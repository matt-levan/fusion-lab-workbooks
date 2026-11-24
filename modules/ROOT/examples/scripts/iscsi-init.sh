#!/bin/bash
# iSCSI Initiator Configuration and Discovery Script for OpenShift Nodes
# Run from a workstation or bastion with oc CLI configured and authenticated
#
# Environment variables (with defaults matching fusion-access-san-attrs.adoc):
#   SCALE_NODE_IP       - IBM Storage Scale node IP (default: 10.10.10.202)
#   ISCSI_TARGET_IQN    - iSCSI target IQN (default: iqn.2022-06.com.scale.scalenode1:tgt0)
#   NODE_SELECTOR       - Node selector for worker pool (default: node-role.kubernetes.io/worker)

set -e

: "${SCALE_NODE_IP:=10.10.10.202}"
: "${ISCSI_TARGET_IQN:=iqn.2022-06.com.scale.scalenode1:tgt0}"
: "${NODE_SELECTOR:=node-role.kubernetes.io/worker}"

echo "=== iSCSI Initiator Discovery and Login for OpenShift Nodes ==="
echo "Target Scale IP: ${SCALE_NODE_IP}"
echo "Target IQN:      ${ISCSI_TARGET_IQN}"
echo "Node Selector:   ${NODE_SELECTOR}"

# 1. Retrieve worker node IQNs (informational)
# The lab does not need these values: targetcli-config.sh sets generate_node_acls=1, so the
# target creates a dynamic ACL for any initiator IQN that logs in. This step is kept for
# reference. If you later switch to explicit ACLs, use these IQNs with
#   targetcli /iscsi/<target-iqn>/tpg1/acls create <initiator-iqn>
echo ""
echo "=== Step 1: Retrieving Node Initiator IQNs (informational, not required with dynamic ACLs) ==="
for NODE in $(oc get nodes -l "${NODE_SELECTOR}" -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Node: ${NODE} ---"
  oc debug node/"${NODE}" -- chroot /host cat /etc/iscsi/initiatorname.iscsi 2>/dev/null
done

# 2. Discover iSCSI targets
echo ""
echo "=== Step 2: Running iSCSI Discovery ==="
for NODE in $(oc get nodes -l "${NODE_SELECTOR}" -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Discovery on ${NODE} ---"
  oc debug node/"${NODE}" -- chroot /host iscsiadm -m discovery -t sendtargets -p "${SCALE_NODE_IP}" 2>/dev/null
done

# 3. Login to iSCSI target
echo ""
echo "=== Step 3: Logging into iSCSI Target ==="
for NODE in $(oc get nodes -l "${NODE_SELECTOR}" -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Login on ${NODE} ---"
  oc debug node/"${NODE}" -- chroot /host iscsiadm -m node -T "${ISCSI_TARGET_IQN}" -p "${SCALE_NODE_IP}" -l 2>/dev/null
done

# 4. Verify block devices and multipath
echo ""
echo "=== Step 4: Verifying Block Devices ==="
for NODE in $(oc get nodes -l "${NODE_SELECTOR}" -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- Devices on ${NODE} ---"
  oc debug node/"${NODE}" -- chroot /host lsblk 2>/dev/null
  echo "--- Multipath on ${NODE} ---"
  oc debug node/"${NODE}" -- chroot /host multipath -ll 2>/dev/null
done

echo ""
echo "=== iSCSI Initiator Verification Complete ==="
