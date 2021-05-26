data "template_file" "gpu_node" {
  template = file("${path.module}/gpu_node.tpl")

  vars = {
    kube_token      = var.kube_token
    primary_node_ip = var.controller_address
    kube_version    = var.kubernetes_version
    storage         = var.storage
  }
}

resource "metal_device" "gpu_node" {
  hostname         = format("${var.cluster_name}-gpu-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_gpu
  plan             = var.plan_gpu
  facilities       = [var.facility]
  user_data        = data.template_file.gpu_node.rendered
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-gpu"]

  billing_cycle = "hourly"
  project_id    = var.project_id

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl cordon ${self.hostname} || echo \"If unsuccessful, set KUBECONFIG for your local kubectl for cluster to active, and cordon ${self.hostname} manually.\""
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl drain ${self.hostname} --delete-local-data --ignore-daemonsets || echo \"If unsuccessful, set KUBECONFIG for your local kubectl for cluster to active, and drain ${self.hostname} manually.\""
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete node ${self.hostname} || echo \"If unsuccessful, set KUBECONFIG for your local kubectl for cluster to active, and delete node ${self.hostname} manually.\""
  }
}

