echo -e "\e[1;34m********************************************\e[0m"
echo -e "\e[1;34m*          GitLab stack Setup Script       *\e[0m"
echo -e "\e[1;34m********************************************\e[0m"
echo ""

# Check command line arguments either setup or runner 
if [ "$1" = "setup" ]; then
    # Check if /srv exists
    if [ ! -d "/srv" ]; then
        mkdir /srv
    fi
    # Run docker compose in detached mode
    echo -e "Waiting for GitLab stack to start..."
    docker-compose up -d
    # Connect to the gitlab container and execute openssl commands
    echo -e "Setting up SSL certificates..."
    docker exec -it gitlab sh -c "openssl genrsa -out /etc/gitlab/ssl/ca.key 2048" > /dev/null 2>&1
    docker exec -it gitlab sh -c "openssl req -new -x509 -days 365 -key /etc/gitlab/ssl/ca.key -subj "/C=CN/ST=GD/L=SZ/O=GITLAB/CN=GITLAB" -out /etc/gitlab/ssl/ca.crt" > /dev/null 2>&1
    docker exec -it gitlab sh -c "openssl req -newkey rsa:2048 -nodes -keyout /etc/gitlab/ssl/gitlab.example.com.key -subj "/C=CN/ST=GD/L=SZ/O=GITLAB/CN=*gitlab.example.com" -out  /etc/gitlab/ssl/gitlab.example.com.csr" > /dev/null 2>&1
    docker exec -it gitlab sh -c 'printf "subjectAltName=DNS:gitlab.example.com,DNS:www.example.com" > /tmp/extfile.cnf && openssl x509 -req -extfile /tmp/extfile.cnf -days 365 -in /etc/gitlab/ssl/gitlab.example.com.csr -CA /etc/gitlab/ssl/ca.crt -CAkey /etc/gitlab/ssl/ca.key -CAcreateserial -out /etc/gitlab/ssl/gitlab.example.com.crt' > /dev/null 2>&1
    docker exec -it gitlab sh -c "chmod 600 /etc/gitlab/ssl/*" 
    echo -e "SSL certificates setup completed."
    # Generate a random password for root user
    echo -e "Generating root password..."
    ROOT_PASSWORD=$(openssl rand -base64 12)
    echo -e "Root password: \e[1;32m$ROOT_PASSWORD\e[0m"
    echo -e "Reconfiguring GitLab...(This may take a while do not interrupt)"
    docker exec -it gitlab gitlab-rails runner "puts user = User.where(id: 1).first; user.password = user.password_confirmation = '$ROOT_PASSWORD'; user.save!" > /dev/null 2>&1
    # Reconfigure and restart gitlab
    docker exec -it gitlab gitlab-ctl reconfigure > /dev/null 2>&1
    docker exec -it gitlab gitlab-ctl restart > /dev/null 2>&1
    echo -e "GitLab setup completed."
    echo -e "Setting up GitLab runner..."
    # Download the cert file using openssl from gitlab-runner 
    docker exec -it gitlab-runner sh -c "openssl s_client -connect gitlab.example.com:443 -showcerts </dev/null 2>/dev/null | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p' > /usr/local/share/ca-certificates/gitlab.example.com.crt" > /dev/null 2>&1
    docker exec -it gitlab-runner update-ca-certificates > /dev/null 2>&1
    echo -e "GitLab runner setup completed."

elif [ "$1" = "register" ]; then
    # Check if gitlab-runner container exists
    if [ ! "$(docker ps -q -f name=gitlab-runner)" ]; then
        echo -e "\e[1;31mGitLab runner container not found. Please run the setup command first.\e[0m"
        exit 1
    fi
    # Register the runner
    docker exec -it gitlab-runner gitlab-runner register
    # edit the config.toml file and add the network_mode = "gitlab-network" to the [[runners]] section
    docker exec -it gitlab-runner sh -c "tac /etc/gitlab-runner/config.toml | sed '0,/network_mtu = 0/s//network_mode = \"gitlab-network\"/' | tac > /tmp/config.toml.tmp && mv /tmp/config.toml.tmp /etc/gitlab-runner/config.toml"
    docker exec -it gitlab-runner gitlab-runner restart > /dev/null 2>&1
else
    echo -e "\e[1;31mInvalid argument. Please use either setup or register\e[0m"
fi