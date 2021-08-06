# Rrport Feedback

> Felix Cai 2021.7.28

#### CKP-01 | Proper Usage of And Type

Fixed

#### CKP-02 | Missing Zero Address Validation

Fixed

`_acceptToken` is allowed to be set to zero address.

#### CKP-03 | Missing Emit Events

Hold

These events are not necessary.

#### CKP-04 | Strengthen Transfer Security

Fixed

#### CKP-05 | Missing Updating Process With `grant.currentRound`

Hold

This is stayed to be compatible with the V1 contract interface and maintain consistency. The data itself is meaningless.

#### CKP-06 | Wrong Logic In `banProject()`

Fixed

Updated the correct BAN logic. The `project.grants` will not be affected by banning the project, and the corresponding methods has been adjusted too.

#### CKP-07 | Priviledged Ownership

Fixed

As solved in CKP-06, `banProject` will now only block projects from participating in SupportPool.

In the actual scenario, projects that do not comply with the provisions of the sponsor (who provided the SupportPool) will be refused to participate in the allocation.

#### CKP-08 | Missing Check In Function `grant.changeSetTime()`

Hold

Considering the change time requirements of sponsors in actual use, the flexibility of this administrator interface is retained.

#### CKP-09 | Discussion For `grant.dangerSetArea()`

The `dangerSetArea()` method was added later in V1. Due to some ticket swiping behavior, sponsors and platforms hope to adjust the results as fair as possible, which is undoubtedly a centralized behavior. We added a new mechanism to v2. For the time being until these mechanisms can effectively counter attacks, this brutal centralized intervention will remain.

In all scenarios using `dangersetarea()`, we will make announcements in the community.

#### CKP-10 | Function `uploadProject()` Not Restricted

Hold

The duplicated check is exist, as `require(project.createAt == 0);`.

#### CKP-11 | Discussion For DORA_ID

DoraID contract has completed the audit.

#### CKP-12 | Discussion For Function `receive()`

The `receive()` method is to allow some sponsors who are not easy to call the contract directly to donate directly through their Wallets. Some Wallets automatically calculate gasLimit, or they need to manually set higher values.

Anyway this method is available when accepting native tokens (like ETH in ethereum).
