import boto3
import os
import logging
import time

sagemaker_client = boto3.client('sagemaker', region_name=os.environ['REGION'])
ecr_client = boto3.client('ecr', region_name=os.environ['REGION'])
image_type = os.environ['IMAGE_TYPE']

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info("Image handler event: %s", event)
    try:
        action_type = event['detail']['action-type']
        image_tag = event['detail']['image-tag']
        image_digest = event['detail']['image-digest']
        account_id = event['account']
        region = event['region']
        domain_name = os.environ['DOMAIN_NAME']

        if action_type == "PUSH":
            handle_image_push(image_tag, image_digest, domain_name, account_id, region)
        elif action_type == "DELETE":
            handle_image_delete(image_tag, domain_name)
        else:
            logger.error(f"Unrecognized action type: {action_type}")
    except KeyError as e:
        logger.error(f"Key error in event structure: {str(e)}")
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")


def handle_image_push(image_tag, image_digest, domain_name, account_id, region):
    try:
        repo_name = os.environ['REPO_NAME']

        images_with_digest = ecr_client.describe_images(
            repositoryName=repo_name,
            imageIds=[{'imageDigest': image_digest}])['imageDetails']

        logger.info(f"Images with digest: {images_with_digest}")

        if images_with_digest:
            image = images_with_digest[0]
            if len(image.get('imageTags', [])) > 1:
                logger.error(f"Cannot add image to SM with tag {image_tag} because the image is already attached with tag {image['imageTags'][0]}")
                return

        custom_app_config_name = 'custom-app-config'
        sagemaker_client.create_image(
            Description=f'Custom {image_type} image',
            DisplayName=image_tag,
            ImageName=image_tag,
            RoleArn=os.environ['SM_ROLE_ARN']
        )
        logger.info(f"Image created: {image_tag}")

        waiter = sagemaker_client.get_waiter('image_created').wait(
            ImageName=image_tag,
            WaiterConfig={
                'Delay': 10,
                'MaxAttempts': 5
            }
        )
        logger.info("Image created successfully.")

        sagemaker_client.create_image_version(
            BaseImage=f"{account_id}.dkr.ecr.{region}.amazonaws.com/{repo_name}:{image_tag}",
            ImageName=image_tag
        )
        logger.info(f"Image version created: {image_tag}")

        create_default_app_image_config(custom_app_config_name)
        update_domain_images(domain_name, image_tag, custom_app_config_name)

    except Exception as e:
        logger.error(f"Error processing image push: {str(e)}")


def handle_image_delete(image_tag, domain_name):
    try:
        existing_images = sagemaker_client.describe_domain(DomainId=domain_name)['DefaultUserSettings'][f'{image_type}AppSettings']['CustomImages']
        logger.info(f"Current custom images: {existing_images}")

        updated_images = [img for img in existing_images if img['ImageName'] != image_tag]
        sagemaker_client.update_domain(
            DomainId=domain_name,
            DefaultUserSettings={
                f'{image_type}AppSettings': {
                    'CustomImages': updated_images
                }
            },
            DefaultSpaceSettings={
                'ExecutionRole': os.environ['SM_ROLE_ARN'],
                f'{image_type}AppSettings': {
                    'CustomImages': updated_images
                }
            }
        )
        logger.info(f"Detached image from domain: {image_tag}")
        sagemaker_client.delete_image(ImageName=image_tag)
        logger.info(f"SageMaker image deleted: {image_tag}")

    except Exception as e:
        logger.error(f"Error processing image delete: {str(e)}")


def create_default_app_image_config(app_config_name):
    try:
        sagemaker_client.describe_app_image_config(AppImageConfigName=app_config_name)
        logger.info(f"Default app image config '{app_config_name}' already exists.")
    except sagemaker_client.exceptions.ResourceNotFound:
        config = {
            "AppImageConfigName": app_config_name
        }

        config[f"{image_type}AppImageConfig"] = {
            "FileSystemConfig": {
                "MountPath": "/home/sagemaker-user",
                "DefaultUid": 1000,
                "DefaultGid": 100
            }
        }

        sagemaker_client.create_app_image_config(**config)
        logger.info(f"Default app image config created")


def update_domain_images(domain_name, image_tag, app_config_name):
    try:
        domain = sagemaker_client.describe_domain(DomainId=domain_name)
        user_settings = domain.get('DefaultUserSettings', {})
        app_settings = user_settings.get(f'{image_type}AppSettings')

        if app_settings and 'CustomImages' in app_settings:
            logger.info(f"{image_type}AppSettings found, updating with new image.")
            custom_images = app_settings['CustomImages']

            custom_images.append({
                'ImageName': image_tag,
                'ImageVersionNumber': 1,
                'AppImageConfigName': app_config_name
            })
        else:
            logger.info(f"No {image_type}AppSettings found, initializing with the first custom image.")
            custom_images = [{
                'ImageName': image_tag,
                'ImageVersionNumber': 1,
                'AppImageConfigName': app_config_name
            }]
            logger.info(f"Initializing {image_type}AppSettings with the first custom image.")

        sagemaker_client.update_domain(
            DomainId=domain_name,
            DefaultUserSettings={
                f'{image_type}AppSettings': {
                    'CustomImages': custom_images
                }
            },
            DefaultSpaceSettings={
                'ExecutionRole': os.environ['SM_ROLE_ARN'],
                f'{image_type}AppSettings': {
                    'CustomImages': custom_images
                }
            }
        )
        logger.info(f"Domain updated with image: {image_tag}")
    except Exception as e:
        logger.error(f"Error updating domain with image: {str(e)}")
