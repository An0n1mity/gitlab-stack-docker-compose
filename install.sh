echo "********************************************"
echo "*          GitLab stack Setup Script             *"
echo "********************************************"
echo ""

# Check command line arguments either setup or runner 
if [ "$1" = "setup" ]; then
    # Check if /srv exists
    if [ ! -d "/srv" ]; then
        mkdir /srv
    fi
    # Run docker compose in detached mode
    echo "Waiting for GitLab stack to start..."
    docker-compose up -d
    # Connect to the gitlab container and execute openssl commands
    echo "Setting up SSL certificates..."
    docker exec -it gitlab sh -c "openssl genrsa -out /etc/gitlab/ssl/ca.key 2048" > /dev/null 2>&1
    docker exec -it gitlab sh -c "openssl req -new -x509 -days 365 -key /etc/gitlab/ssl/ca.key -subj "/C=CN/ST=GD/L=SZ/O=GITLAB/CN=GITLAB" -out /etc/gitlab/ssl/ca.crt" > /dev/null 2>&1
    docker exec -it gitlab sh -c "openssl req -newkey rsa:2048 -nodes -keyout /etc/gitlab/ssl/gitlab.example.com.key -subj "/C=CN/ST=GD/L=SZ/O=GITLAB/CN=*gitlab.example.com" -out  /etc/gitlab/ssl/gitlab.example.com.csr" > /dev/null 2>&1
    docker exec -it gitlab sh -c 'printf "subjectAltName=DNS:gitlab.example.com,DNS:www.example.com" > /tmp/extfile.cnf && openssl x509 -req -extfile /tmp/extfile.cnf -days 365 -in /etc/gitlab/ssl/gitlab.example.com.csr -CA /etc/gitlab/ssl/ca.crt -CAkey /etc/gitlab/ssl/ca.key -CAcreateserial -out /etc/gitlab/ssl/gitlab.example.com.crt' > /dev/null 2>&1
    docker exec -it gitlab sh -c "chmod 600 /etc/gitlab/ssl/*" 
    echo "SSL certificates setup completed."
    echo "Reconfiguring GitLab..."
    # Reconfigure and restart gitlab
    docker exec -it gitlab gitlab-ctl reconfigure > /dev/null 2>&1
    docker exec -it gitlab gitlab-ctl restart > /dev/null 2>&1
    echo "GitLab setup completed."
    echo "Setting up GitLab runner..."
    # Download the cert file using openssl from gitlab-runner 
    docker exec -it gitlab-runner sh -c "openssl s_client -connect gitlab.example.com:443 -showcerts </dev/null 2>/dev/null | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p' > /usr/local/share/ca-certificates/gitlab.example.com.crt" > /dev/null 2>&1
    docker exec -it gitlab-runner update-ca-certificates > /dev/null 2>&1
    echo "GitLab runner setup completed."

elif [ "$1" = "register" ]; then
    # Register the runner
    docker exec -it gitlab-runner gitlab-runner register
    docker exec -it gitlab-runner gitlab-runner restart > /dev/null 2>&1

else
    echo "Invalid argument. Please use either setup or register"
fi