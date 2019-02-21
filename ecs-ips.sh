while getopts "c:s:" o; do
  case "${o}" in
    c)
      CLUSTER=${OPTARG}
      ;;
    s)
      SERVICE_NAME=${OPTARG}
      ;;
  esac
done
shift $((OPTIND-1))

if [[ -z "${CLUSTER}" ]] ; then
  echo "Usage: $0 -c <cluster> [-d <docker contianer name>]"
  exit 1
fi

if [[ -z "${SERVICE_NAME}" ]] ; then
  LISTED_TASKS=$(aws ecs list-tasks --cluster $CLUSTER --output text | cut -f2)
else
  LISTED_TASKS=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE_NAME --output text | cut -f2)
fi

TASK_CONTAINER_INSTANCE_ARNS=$(aws ecs describe-tasks --cluster $CLUSTER --tasks $LISTED_TASKS --query 'tasks[*].[containerInstanceArn]' --output text)

EC2_IDS=$(aws ecs describe-container-instances --cluster $CLUSTER --container-instances $TASK_CONTAINER_INSTANCE_ARNS --query 'containerInstances[*].[ec2InstanceId]' --output text)

aws ec2 describe-instances --instance-ids $EC2_IDS --query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddresses[0].[PrivateIpAddress]' --output text
