# pool-trigger
A resource solely for triggering concourse builds when resources are
added to pools.

When a single job is configured to trigger on this resource it
guarantees one triggered build for every unclaimed lock that is in the
pool when the resource is created and one for each lock added
afterwards.

Do not use it to get or put locks.

### ATTENTION
##### Behaviour is only guaranteed if 
###### 1. A SINGLE job triggers on the configured pool.
###### 2. This job uses pool-resource to claim locks on the same pool.
###### 3. Locks are NEVER removed from that pool by other means.

#### Behaviour

##### In
no-op

##### Out
no-op

##### Check
1. Checks for newly added locks since the last version (or any currently
   unclaimed if starting fresh with no previous version) and adds these
to the tally in `.pending-triggers`
2. If the `.pending_triggers` tally is greater than zero it decrements
   the tally and returns the previous commit hash reference
3. If the `.pending_triggers` tally is zero it returns no new references

Note: If `check` fails to push the updated `.pending_triggers` tally it
will fail out. This should only happen if other commits are pushed in
between fetching and pushing the tally. It should resolve itself on the
next check with no intervention.
