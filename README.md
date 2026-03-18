# Feature Flag Repository

## Overview

This repository provides tools and utilities for:
- Managing feature flags across different environments
- Updating feature flag status

## Prerequisites

Before you begin, ensure you have the following installed:
- **Git** (version 2.0 or higher)
- **Node.js** (version 14.x or higher) - if working with JavaScript/TypeScript files
- **Python** (version 3.8 or higher) - if working with Python scripts
- **Ruby** (version 2.7 or higher) - if working with Ruby scripts

## Getting Started

### Clone the Repository

To clone this repository to your local machine, use one of the following methods:

#### Using HTTPS:
```bash
git clone https://github.com/ryandedumo-ujet/feature_flag.git
```

### Navigate to the Repository

```bash
cd feature_flag
```

## Repository Structure

```
feature_flag/
│   └── flags.json      # Feature flag definitions
│   ├── patch.sh        # Main Script
│   └── README.md       # This file
```

## Usage Examples

### Restore Feature Flags to Default

Use this when you want to reset all feature flags to their default state:

# Restore specific tenant to default

Fill in the required parameters:
   - **`project-id`**: Environment name which can be found in 1Password (e.g., `ujet-staging-qca01`, `ujet-staging-tst01`)
   - **`base-url`**: Tenant url (e.g., `https://callteam-sfco.qca01.g.ujetstage.co/`)

```bash
./patch.sh project-id base-url restore_default
```

# Update single feature flag to a specific tenant

Fill in the required parameters:
   - **`project-id`**: Environment name which can be found in 1Password (e.g., `ujet-staging-qca01`, `ujet-staging-tst01`)
   - **`base-url`**: Tenant url (e.g., `https://callteam-sfco.qca01.g.ujetstage.co/`)
   - **`featureflag`**: Feature flag name which will be updated (e.g., `virtual-callback`, `voicebot`)
   - **`status`**: Boolean status (e.g., `true`, `false`)

```bash
./patch.sh project-id base-url featureflag status
```

