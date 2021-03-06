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

## Git Workflow

A _single version_ in a control-repo will describe configuration for _all_ SDLC Deployment Tiers. Yes, you read that correctly. No, it's not a mistake.

In exchange for reducing the amount of Puppet code "vendored" into the site directory, the need for Git branches in the control-repo to hold different versions of code is eliminated. Branches still exist, but they serve a different purpose than traditional r10k branches do. Each branch holds the same code version at the end of a rapid promotion cycle.

Profiles for applications that need to be promoted on their own independent cadence are broken out into separate Puppet modules.

Hiera data is used to define which version of each Puppet module should be deployed to each Deployment Tier.

### Branches

Branches are classified into one of three different branch types. Main branches, Feature branches, and Deployment Tier branches.

#### Main branches

There are two main branches:

1. Integration
2. Master

All development flows through these branches. Feature branches are forked from master and merged to integration. Integration is promoted to master.

All commits in the master branch are deployable VERSIONS.

Differences between SDLC Deployment Tiers are NOT represented by different VERSIONS in the control-repo. They are represented instead by data in Hiera.

#### Feature branches

Work occurs in feature branches. The process of making a change is to fork a new feature branch off of master; do work, iterate, test, canary deploy, etc. When ready rebase and file a pull request (PR) against integration.

When the PR is accepted and merged to integration, the work is on its way to being deployed.

#### Deployment Tier branches

No work occurs in Deployment Tier branches, no new commits, and no merges. Deployment Tier branches exist only to enumerate the Deployment Tiers that exist, and to associate them with a specific VERSION of code.

### Developing code

1. Check out the master branch
2. Create a new feature branch based on master
3. Work. Test. Iterate

### Merging changes

Real merging ONLY happens from feature branches into the integration branch.

1. Check out the integration branch
2. Do a `git merge` against your feature branch
3. Resolve any merge conflicts if necessary

### Promoting changes to master

After merging feature branches (individual changes ready to deploy or related feature work that must be deployed together), the integration branch is promoted to master.

1. Check out the master branch
2. Do a `git merge integration`. It should be a fast-forward merge

### Deploying Code

Deploying code means pushing a VERSION of code to a Deployment Tier.

1. Check out the Deployment Tier branch you want to deploy to
2. Do a `git reset --hard <VERSION>`
3. Force-push changes

## Change Workflow

### Change types

Changes are classified into three different change types. Control-repo changes, Module changes, and Hiera changes.

#### Control-repo changes

Any change to code directly committed to the control-repo and NOT inside the `data` or `hieradata` directory. This includes vendored Puppet code (`site/`) as well as things like hiera.yaml and the Puppetfile.

Control-repo changes are promotion-blocking. The VERSION of code containing the control-repo change must be fully deployed out to production before non-blocking changes may proceed past it.

#### Module changes

Module changes are made in git, but not in the control-repo. This catagory of change represents de-coupled work in a separate git repo.

Module changes are non-blocking. In conjunction with Hiera changes, a module change may be deployed to the `stage` SDLC Deployment Tier, and other blocking and non-blocking changes may proceed past it through the SDLC Deployment Tier process.

#### Hiera changes

Any code committed to the control-repo INSIDE the `data` or `hieradata` directory is a Hiera change.

Hiera changes are promotion-blocking. However, because Hiera changes may be designed such that they are specific to an SDLC Deployment Tier, a Hiera change promoted all the way to production may only affect a single SDLC Deployment Tier.

### Change Principles

In general, VERSION changes in the control-repo should flow very rapidly through the SDLC Deployment Tiers. Control-repo changes should be rare. Module changes are fully independent and do not impact deployments.

Hiera changes are blocking, BUT they should be scoped to an SDLC Deployment Tier, thus enabling easy, rapid promotion.

## Separating app deployment cadence from control-repo deployment cadence

Control-repo deployment cadence should be fast and simple. A VERSION in master is deployed to development, then testing, etc., until production. Ideally this would happen no less than daily.

Application changes may move through the SDLC more ponderously, and independent of one another. To handle this:

* Put each application in its own module
* Use Hiera to define which application module versions should be deployed to each Deployment Tier
* Make small Hiera data changes to update a module version in a single SDLC Deployment Tier. The Hiera change will be quickly deployed through all environments, and the result will be that in a SINGLE Deployment Tier, one new application version will be deployed.

### R10K Puppetfile RefLookup

See the Puppetfile in the `example-usage` directory.

In the Puppetfile, some modules use a new parameter, `ref_lookup`, to tie the version of the module which will be deployed to a specification in Hiera data.

In Hiera, each Deployment Tier data file enumerates which application module versions should be deployed to that SDLC Deployment Tier.

#### Implementation

* Install the `r10k_puppetfile_ref_lookup.rb` file into the root of the control-repo, next to the Puppetfile
* Make sure a `hiera.yaml` file is in the control-repo. That is, use a per-environment `hiera.yaml`, Hiera 5 style
* Add the following two lines to the top of the Puppetfile:

    ```ruby
    require_relative 'r10k_puppetfile_ref_lookup'
    extend R10K::Puppetfile::RefLookup
    ```

* Lookups performed during r10k runs have no facts. You need to set the value of any variables you want Hiera to interpolate, such as "environment" or "deployment\_tier". There is really only one variable value available, which is `branch_name`. Set variables in scope like this.

    ```ruby
    scope['environment'] = branch_name
    scope['deployment_tier'] = branch_name
    scope['company'] = "rgbank"
    ```

* When developing in a feature branch, the branch name is not a good analog for Deployment Tier. Therefore, when a `ref_lookup` performed using the regular scope failsa second lookup is performed using a fallback scope. Set static values in the fallback scope to let feature branches target the first tier of deployment.

    ```ruby
    fallback_scope['environment'] = branch_name
    fallback_scope['deployment_tier'] = "development"
    fallback_scope['company'] = "rgbank"
    ```

* Use `ref_lookup` in place of `ref` (git) or version numbers (Forge) for modules which need to be deployed/promoted through Deployment Tiers at rate different from the rate changes are made to the control-repo.

    ```ruby
    mod 'puppetlabs/stdlib', ref_lookup: 'module::stdlib::version'

    mod 'rgbank/profile_fto',
      git: 'https://github.rgbank.com/puppet/profile_fto.git',
      ref_lookup: 'module::profile_fto::version'
    ```

* Create Hiera data per Deployment Tier defining which module versions to use _in that Deployment Tier_. For example, this Hiera data shows a new version of stdlib being tested in development, while a slightly older version is still used in production.

   ```yaml
   # deployment_tier/development.yaml
   ---
   module::profile_fto::version: "1.2.0"
   module::stdlib::version: "4.16.0"
   ```

   ```yaml
   # deployment_tier/prestage.yaml
   ---
   module::profile_fto::version: "1.1.0"
   module::stdlib::version: "4.16.0"
   ```

   ```yaml
   # deployment_tier/production.yaml
   ---
   module::profile_fto::version: "1.1.0"
   module::stdlib::version: "4.15.0"
   ```

### Deploy an application to a Deployment Tier

At a high level, the process of updating an application and deploying it to a single Deployment Tier is as follows. Assume we're deploying a newer version of the FTO app, 1.2.0 to the prestage Deployment Tier.

1. Make a feature branch for the deployment
2. In the feature branch, update Hiera data for the prestage Deployment Tier. For example:
    * Open `data/deployment_tiers/prestage.yaml`
    * Update the `module::profile_fto::version` parameter to `1.2.0`
    * Commit the change
3. Make a pull request to the integration branch in git
4. If approved, the PR will be merged, integration promoted to master, and the new VERSION of Puppet code rolled out to the Deployment Tiers. The new code will have no impact in any Deployment Tier except prestage, where it will cause the new version of the FTO profile to be deployed.

## Final Thoughts

This workflow has multiple work queues.

The single most important change queue in the control-repo. This is a fast-paced queue. It is imperative that changes made in this queue are small, fast, rolled out quickly, and rolled out regularly because everything needs to go through this queue regardless of which Deployment Tier the change targets.

Every module CAN be a separate queue, non-blocking to change deployment, which can be worked at its own pace. It is related to the control-repo queue because when it's time to deploy a module change to one of the Deployment Tiers, a small data change must be pushed through the control-repo queue.

Occasionally, there may come a time when a global-effect change to the control repo needs to be deployed. When this happens, everything slows down and backs up behind this change as it works its way through the SDLC tiers. These global-effect changes should therefore be minimized to avoid blocking deployment of independent modules.
