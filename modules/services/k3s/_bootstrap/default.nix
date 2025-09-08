{ kubenix, ... }:
{
  imports = [ kubenix.modules.k8s ];
  kubernetes.resources.clusterRoleBindings.cluster-admins = {
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io";
      kind = "ClusterRole";
      name = "cluster-admin";
    };
    subjects = [
      {
        kind = "User";
        name = "sini";
      }
      {
        kind = "User";
        name = "shuo";
      }
    ];
  };
}
