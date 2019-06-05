## ECS

Scripts used to grab private IP's of EC2 instances running through ECS.
Used for easy SSH

Usage: ```ecs-ips -c clusterName```
Usage: ```ecs-ips -c clusterName -s serviceName```

## EB

Script used to deploy an EB dockerized application

Usage: ```eb-deploy```

Note: Still primitive and doesn't account for environments or profiles from args which would be nice.
(ex. ```eb-deploy -e dev -p aws-profile```)
