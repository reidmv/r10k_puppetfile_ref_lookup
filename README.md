# R10K Puppetfile RefLookup

This code demonstrates integrating gitflow, a simple trunk-based development workflow, with r10k branch-based Deployment Tiers.

The objective is to be able to promote new features through a very short Git pipeline, `feature_branch` => `integration` => `production`, while being able to throttle or control the speed at which changes to individual applications are pushed to Software Development Lifecycle (SDLC) deployment tiers.
