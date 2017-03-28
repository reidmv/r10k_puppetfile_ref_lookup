# R10K Puppetfile RefLookup

This project provides tooling for and describes a workflow for developing and deploying Puppet code which manages multiple applications which vary in their deployment cadence.

## Overview

Promote new features through a short Git pipeline:

1. feature\_branch
2. integration
3. master

Then, promote those complete code versions through linear Software Development Lifecycle (SDLC) deployment tiers:

1. development
2. test
4. stage
5. production

AND maintain per-application control over the speed at which changes to each application are deployed to each SDLC deployment tier.

## Problem Description

RG Bank uses Puppet to manage their Business Operations application infrastructure. This infrastructure consists of baseline configuration and 11 individual applications, some single-tier apps, some multi-tier apps. These applications are developed on RG Bank owned and managed infrastructure called Lab. Two separate Managed Service Providers (MSPs) then consume RG Bank's Puppet code to deploy and manage the apps.

RG Bank has 5 deployment tiers, or environments, which changes are pushed to in order as part of the deployment process. These deployment tiers are:

1. development
2. test
3. prestage
4. stage
5. production

Each of the 11 applications RG Bank manages have their own Software Development Lifecycle (SDLC) cadence. Changes to each app are first deployed to development. Those changes are then promoted to test, to prestage, and so on until reaching production.

Different applications are developed and deployed at widely varying cadences. Baseline configuration changes to services like ntp and dns move very quickly through development all the way to production. Changes to one of the apps, FTO, move more slowly though. Changes to this app might be left in the "test" deployment tier for a long time to bake-in, and make sure there are no problems after long periods of operation.

Frequently, there is a need for changes to baseline configuration or rapidly-developing apps to come up from behind an existing change already baking in the test deployment tier, and pass through on to prestage or production.

Puppet manages the configuration on all the servers in every deployment tier. The traditional r10k workflow accounts for this, but does not account for multiple parallel apps represented by the codebase being deployed to SDLC deployment tiers at differing rates.

This project aims to provide a workflow separating _development_ of Puppet code from _deployment_ of Puppet code. It accomplishes this using Git, Hiera, and R10K.

## Development of Puppet Code

## Deployment of Puppet Code
