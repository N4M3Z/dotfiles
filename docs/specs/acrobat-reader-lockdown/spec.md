# acrobat-reader-lockdown Specification

## Purpose

Acrobat Reader starts locked down, and the deployer asks for root only on a

## Requirements

### Requirement: Acrobat Reader Starts Locked Down

The deployer MUST install Adobe's system-wide lockdown preferences on every Mac that applies these
dotfiles. The preferences MUST turn off product updates, Adobe online services, notifications,
upsell, the app center, and the feedback icon. Root MUST own the installed file, so a process of the
user cannot change it.

#### Scenario: Fresh Mac applies the dotfiles

- **WHEN** the deployer runs on a Mac that has no lockdown preferences
- **THEN** it installs them as root with mode 644, after the owner enters the admin password once
- **AND** the next Acrobat Reader start shows no PDF Spaces cards, no trial offer, and no sign-in
  control

#### Scenario: Owner signs after the lockdown

- **WHEN** the owner signs a PDF with the PostSignum certificate from Keychain
- **THEN** Acrobat Reader signs it, because certificate signing is not an Adobe online service

### Requirement: The Deployer Asks For Root Only On A Difference

The deployer MUST compare the wanted preferences with the installed file before it asks for the
admin password. It MUST NOT ask when the two files are identical. It MUST restore the wanted file
when they differ.

#### Scenario: Mac already carries the lockdown

- **WHEN** the deployer runs and the installed preferences match the wanted ones byte for byte
- **THEN** it finishes without a password prompt

#### Scenario: Adobe installer rewrites the preferences

- **WHEN** a Reader installer or a person changes the installed preferences
- **THEN** the next deployer run asks for the admin password and installs the wanted file again
