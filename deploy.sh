#!/bin/bash

echo 'Starting to Deploy...with yum 3'

# Install required dependencies
sudo yum update
sudo yum upgrade
yes | sudo amazon-linux-extras install java-openjdk11
#yes | sudo yum install nginx
yes | sudo amazon-linux-extras install nginx1
#yes | sudo apt install apt-transport-https ca-certificates curl software-properties-common
#yes | curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
#sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
#apt-cache policy docker-ce
yes | sudo yum install -y yum-utils device-mapper-persistent-data lvm2
yes | sudo yum -y install curl wget unzip awscli aws-cfn-bootstrap nfs-utils chrony conntrack jq ec2-instance-connect socat

yes | sudo yum install docker

# make sure demo docker is not running
#sudo docker rm $(sudo docker stop $(sudo docker ps -a -q --filter ancestor=demo:latest --format="{{.ID}}"))

sudo amazon-linux-extras enable docker
sudo yum -y install docker

sudo systemctl daemon-reload
sudo systemctl enable --now docker

# copy nginx conf to default
sudo cp nginx.conf /etc/nginx/conf.d/default.conf

sudo systemctl restart nginx

# build dockerfile
cd /home/ec2-user/demo
sudo docker build -f Dockerfile -t demo:latest .

# run in detached mode
sudo docker run -p 8080:8080 -d demo:latest

sleep 15

PORT=8080
checkHealth() {
    PORT=$1
    url="http://$HOSTNAME:$PORT/actuator/health"

    pingCount=0
    stopIterate=0
    loopStartTime=`date +%s`
    loopWaitTime=150 ## in seconds

    # Iterate till get 2 success ping or time out
    while [[ $pingCount -lt 2 && $stopIterate == 0 ]]; do
        startPingTime=`date +%s`
        printf "\ncurl -m 10 -X GET $url"
        curl --ipv4 -v $url
        curl -m 10 -X GET $url -o /dev/null 2>&1
        returnCode=$?
        if [ $returnCode = 0 ]
            then
            pingCount=`expr $pingCount + 1`
        fi
        endPingTime=`date +%s`
        pingTimeTaken=`echo " $endPingTime - $startPingTime " | bc -l`
        loopEndTime=`date +%s`
        loopTimeTaken=`echo " $loopEndTime - $loopStartTime " | bc -l`

        echo "Ping time is " $pingTimeTaken
        echo "ReturnCode is $returnCode"
        echo "PingCount is $pingCount "

        waitTimeEnded=`echo "$loopTimeTaken > $loopWaitTime" | bc -l`
        echo "LoopTimeTaken is $loopTimeTaken"
        echo "WaitTimeEnded is $waitTimeEnded"
        # On timeout, if 2 successfully pings not received, stop interaction
        if [[ $pingCount -lt 2 && "$waitTimeEnded" -eq 1 ]];
            then
            stopIterate=1
        fi
        sleep 5
    done

    if [ $stopIterate -eq 1 ]
    then
        if [ $pingCount -lt 2 ]
        then
            echo "PingCount is less than 2"
        else
            echo "Time taken in building took more than $loopWaitTime seconds"
        fi

        exit 1
    fi
}


checkHealth $PORT
checkHealthResponse=$?
if [ checkHealthResponse = 1 ]
    then
        echo "CheckHealth returns 1 that means something went wrong, exiting..."
        exit 1
else
    printf "\n\nService is running on $PORT ...\n\n"
fi

echo 'Deployment completed successfully'