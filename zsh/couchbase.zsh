# Couchbase aliases, functions and env
# (kept out of the personal repo; added in the work fork)

# --- Named directories ---
# Use with `cd <name>` or `~<name>` in any path (e.g. `ls ~cbc/src`)
setopt cdable_vars
hash -d cbc=~/Documents/cb_cloud_pr

# --- Couchbase Server tooling ---
export PATH="/Applications/Couchbase Server.app/Contents/Resources/couchbase-core/bin:$PATH"
export PATH="$HOME/tools/couchbase-server-dev-tools/bin:$PATH"
export PATH="$HOME/tools/couchbase-server-dev-tools-7.6.6-6126/bin:$PATH"

# --- AWS (Capella / DBaaS) ---
export AWS_PROFILE=dbaas-test-0005-temp

# Assume roles into the various DBaaS accounts
assume_cp_stage() {
  cbc-aws-assumerole -account dbaas-stage-0001 -profile cbc-main
}
assume_cp_prod() {
  cbc-aws-assumerole -account dbaas-prod-0001 -profile cbc-main
}
assume_dp_test() {
  cbc-aws-assumerole -account dbaas-test-0005 -profile cbc-main
}
assume_rce_nonprod() {
  cbc-aws-assumerole -account dbaas-rce-nonprod-0001 -profile cbc-main
}
