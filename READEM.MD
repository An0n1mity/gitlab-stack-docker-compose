# GitLab Stack Setup

This repository provides a Docker-based setup for GitLab and GitLab Runner using docker-compose.


### Services

- **GitLab**: 
  - Image: `gitlab/gitlab-ce:latest`
  - Container Name: `gitlab`
  - Hostname: `gitlab.example.com`
  - Ports:
    - `80:80`
    - `443:443`
    - `2222:22`
  - Volumes:
    - `/srv/config:/etc/gitlab`
    - `/srv/logs:/var/log/gitlab`
    - `/srv/data:/var/opt/gitlab`
  - Shared Memory Size: `256m`
  - Networks: `gitlab-network`

- **GitLab Runner**: 
  - Image: `gitlab/gitlab-runner:latest`
  - Container Name: `gitlab-runner`
  - Depends On: `gitlab`
  - Volumes:
    - `/var/run/docker.sock:/var/run/docker.sock`
    - `/srv/gitlab-runner/config:/etc/gitlab-runner`
  - Networks: `gitlab-network`

### Gitlab setup Script

The gitlab-setup script automates the deployment and configuration of the GitLab stack. It supports two modes of operation: `setup` and `register`.

#### Setup

```bash
./gitlab-setup.sh setup
```

- Initializes required directories.
- Starts the GitLab stack.
- Sets up SSL certificates.
- Reconfigures GitLab.
- Sets up GitLab Runner.

#### Register

```bash
./gitlab-setup.sh register
```

- Registers the GitLab Runner.

## Notes

- Ensure Docker and Docker Compose are installed.
- Modify configurations as needed in **docker-compose.yml**.
- SSL certificates are generated for **gitlab.example.com**.
- Runner registration requires manual configuration if using different domain or certificates.
