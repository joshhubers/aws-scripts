set -e

REGION=''
EB_FILE="Dockerrun.aws.json"
VERSION=$(date +%s)
ECR=""
ECR_TAG="${ECR}:staging-${VERSION}"
AWS_PROFILE=""
S3_BUCKET="elasticbeanstalk-bucket"
S3_BUCKET_URL="s3://${S3_BUCKET}"
EBS_APP_NAME=""
EBS_ENV_NAME=""
VERSIONED_EB_FILE="${VERSION}-${EB_FILE}"
ECS_MIGRATION_TASK_NAME=""
ECS_CLUSTER_NAME="default"

# Docker operations
(
  # Build the Docker image (to do asset and template compilation, etc.)
  docker build --pull -t "${ECR}:latest" -f production.dockerfile .
  # Tag the new Docker image to the remote repo (by date)
  docker tag "${ECR}:latest" "${ECR_TAG}"

  # Login to ECR
  $(aws ecr get-login --no-include-email --region "${REGION}" --profile "${AWS_PROFILE}")

  # Push to the remote repo (by date)
  docker push "${ECR_TAG}"
)

# ECS - Run Migrations
(
  ecs-deploy -d "${ECS_MIGRATION_TASK_NAME}" -c "${ECS_CLUSTER_NAME}" -i "${ECR_TAG}" --use-latest-task-def -p "${AWS_PROFILE}" -r "${REGION}"
  TASK_ARN=$(aws ecs run-task --profile "${AWS_PROFILE}" --region "${REGION}" --cluster "${ECS_CLUSTER_NAME}" --task-definition "${ECS_MIGRATION_TASK_NAME}" --query "tasks[0].taskArn" --output text)

  echo "Waiting for task: ${TASK_ARN}"
  aws ecs wait tasks-stopped --cluster "${ECS_CLUSTER_NAME}" --tasks "${TASK_ARN}" --profile "${AWS_PROFILE}" --region "${REGION}"
  waitRet=$?

  if [ ! $waitRet -eq 0 ]; then
    echo "There was an error waiting for the task to stop"
    exit $waitRet
  fi

  retVal=$(aws ecs describe-tasks --profile "${AWS_PROFILE}" --region "${REGION}" --tasks "${TASK_ARN}" --query "tasks[0].containers[0].exitCode")

  if [ ! $retVal -eq 0 ]; then
    echo "The migration task did not complete successfully"
    exit $retVal
  fi

  echo "The migration task has run successfully"
)

# EB - Local prep
(
UPDATED=$(jq --arg ECR "${ECR_TAG}" '.Image.Name = $ECR' ${EB_FILE})

echo ${UPDATED} > ${VERSIONED_EB_FILE}
)

# EB - Update AWS
(
aws s3 cp "${VERSIONED_EB_FILE}" "${S3_BUCKET_URL}" --profile "${AWS_PROFILE}"

aws elasticbeanstalk create-application-version --application-name ${EBS_APP_NAME} --version-label ${VERSION} --profile ${AWS_PROFILE} --region ${REGION} --source-bundle S3Bucket="\"${S3_BUCKET}\"",S3Key="\"${VERSIONED_EB_FILE}\""

aws elasticbeanstalk update-environment --profile ${AWS_PROFILE} --region ${REGION} --application-name ${EBS_APP_NAME} --environment-name ${EBS_ENV_NAME} --version-label ${VERSION}
)
