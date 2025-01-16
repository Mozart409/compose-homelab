# Homelab Compose Stack

This repository contains a collection of containers for various services I run in my homelab. Everything is proxied through Tailscale Serve.

## Table of Contents

- [Services](#services)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Services

This stack includes the following services:

- **SearXNG**: A privacy-respecting metasearch engine.
- **Pinchflat**: A service for managing and downloading media.
- **Dashy**: A customizable dashboard for organizing web apps.
- **Open-WebUI**: A web interface for managing various services.
- **Isaiah**: A service for managing Docker containers.
- **Jellyfin**: A media server for streaming your media.
- **Prometheus**: An open-source systems monitoring and alerting toolkit.
- **Grafana**: A multi-platform open source analytics and interactive visualization web application.

## Getting Started

### Prerequisites

- Docker and Docker Compose installed on your system.
- A Tailscale account for secure networking.

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/mozart409/compose-homelab.git
   cd compose-homelab
   ```

2. Copy the example environment file and fill in your credentials:

   ```bash
   cp .env.example .env
   ```

3. Update the `.env` file with your OpenAI API key and Tailscale Auth Key:

   ```plaintext
   OPENAI_API_KEY=your_openai_api_key
   TS_AUTH_KEY=your_tailscale_auth_key
   ```

4. Start the services:

   ```bash
   docker compose up -d
   ```

## Configuration

### Environment Variables

- **OPENAI_API_KEY**: Your OpenAI API key for accessing OpenAI services.
- **TS_AUTH_KEY**: Your Tailscale authentication key for secure networking.

### Configuration Files

- **dashy-conf.yml**: Configuration for Dashy dashboard.
- **diun.yml**: Configuration for Diun service.
- **isaiah.json**: Configuration for Isaiah service.
- **jellyfin.json**: Configuration for Jellyfin service.
- **ntfy.json**: Configuration for Ntfy service.
- **openwebui.json**: Configuration for Open-WebUI service.
- **pinchflat.json**: Configuration for Pinchflat service.
- **searxng.json**: Configuration for SearXNG service.

### Docker Compose

The `compose.yml` file defines the services and their configurations. Each service is set up to restart unless stopped manually.

## Usage

### Managing Services

- **Start Services**: `docker compose up -d`
- **Stop Services**: `docker compose down`
- **Restart Services**: `docker compose restart`
- **Pull Latest Images**: `docker compose pull`

### Justfile Commands

- **up**: Start and build services.
- **down**: Stop services.
- **clear**: Clear the terminal.
- **pull**: Pull the latest images.
- **restart**: Restart services.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any improvements or bug fixes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

This README provides an overview of the Homelab Compose Stack, detailing the services included, how to get started, configure, and use the stack. For more detailed configuration options, refer to the individual configuration files in the `config` directory.
