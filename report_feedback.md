# Rrport Feedback

> Felix Cai 2021.1.5

#### Exhibit-01: Unlocked Compiler Version Declaration

Fixed

#### Exhibit-02: Proper Usage of "public" and "external" type

Fixed

#### Exhibit-03: Simplifying Existing Code

Fixed

#### Exhibit-03: Simplifying Existing Code

Fixed

#### Exhibit-04: Lack of natspec comments

(-) To do later

#### Exhibit-05: Use SafeMath

(+) SafeMath lib is used in some "dangerous" places, such as multiplication of votes. For the part in the context that has been checked and will not overflow, will remain as it is.

#### Exhibit-6: Missing Important Checks

Fixed

#### Exhibit-7: Potentially Dangerous Operation (Divide before Multiply)

Fixed

#### Exhibit-08: Missing Emit Events

Fixed

#### Exhibit-09: Reducing Lines of Code

(-) The context of the method vote() needs more than the returns values of votingCost(). It will not be changed for the lower gas to call.

#### Exhibit-10: Multiple Storage Reads & Writes

(?) Type struct Project is only valid in storage because it contains a mapping.
