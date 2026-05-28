# Kubernetes Command Reference

This document provides a handy reference for common Kubernetes commands, along with tips to simplify your workflow using aliases. Keeping these commands in a README makes them easily accessible and readable on GitHub.

---

## Setting Up Aliases for Easier Commands

Instead of typing long `kubectl` commands with namespaces every time, you can set up aliases in your shell configuration file.

### Steps:

1. **Open your shell source file**  
   For bash:  
   ```sh
   vi ~/.bashrc
   ```
   For zsh:  
   ```sh
   vi ~/.zshrc
   ```

2. **Add aliases for namespaces and database connections**  
   Example:
   ```sh
   alias auto="kubectl -n autobaml"
   alias hkp="sqlplus user/password@//10.73.620.153:1521/OEST1115"
   ```

3. **Reload your shell configuration**  
   ```sh
   source ~/.bashrc
   ```
   or  
   ```sh
   source ~/.zshrc
   ```

---

## Common Kubernetes Commands

> Replace `auto` with your alias if you use a different namespace.

| Task                                    | Command Example                                  |
|-----------------------------------------|--------------------------------------------------|
| Get available pods                      | `auto get pod`                                   |
| Get deployments                         | `auto get deploy`                                |
| Get ConfigMaps                          | `auto get cm`                                    |
| Delete a pod                            | `auto delete pod <pod-name>`                     |
| Edit a deployment                       | `auto edit deploy <deployment-name>`             |
| Edit a ConfigMap                        | `auto edit cm <configMap-name>`                  |
| Open pod in interactive shell           | `auto exec -it <pod-name> -- sh`                 |
| Check service ports/IPs                 | `auto get svc`                                   |
| Get detailed info about a pod           | `auto describe pod <pod-name>`                   |
| Scale a deployment                      | `auto scale deploy <deployment-name> --replicas=<count>` |
| View logs for a pod                     | `auto logs <pod-name>`                           |
| Get all resources in namespace          | `auto get all`                                   |
| Apply a manifest file                   | `auto apply -f <file.yaml>`                      |
| Delete a resource from a manifest       | `auto delete -f <file.yaml>`                     |
| Port-forward a service                  | `auto port-forward svc/<service-name> <local-port>:<target-port>` |

---

## Tips

- Use `kubectl config get-contexts` and `kubectl config use-context <context>` to switch between clusters.
- Use `kubectl explain <resource>` to get documentation for any resource.
- Use `kubectl get events` to troubleshoot issues in the namespace.
- For frequent commands, consider creating more aliases or shell functions.

---

**Feel free to add more commands as you discover new use cases!**