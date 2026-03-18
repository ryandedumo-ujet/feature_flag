# Feature Flag Repository

## Overview

This repository provides tools and utilities for:
- Managing feature flags across different environments
- Testing feature flag configurations
- Automating feature flag deployments
- Monitoring feature flag states

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

#### Using SSH:
```bash
git clone git@github.com:ryandedumo-ujet/feature_flag.git
```

#### Using GitHub CLI:
```bash
gh repo clone ryandedumo-ujet/feature_flag
```
### Navigate to the Repository

```bash
cd feature_flag
```

### Install Dependencies

Depending on the tools you're using:

#### For Node.js/JavaScript projects:
```bash
npm install
```

#### For Python projects:
```bash
pip install -r requirements.txt
```

#### For Ruby projects:
```bash
bundle install
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
