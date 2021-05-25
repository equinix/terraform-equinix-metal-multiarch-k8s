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
  custom_data      = "${var.controller_address},${var.ssh_private_key_path}"
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-gpu"]

  billing_cycle = "hourly"
  project_id    = var.project_id

  connection {
    type        = "ssh"
    user        = "root"
    host        = split(",", self.custom_data)[0]
    private_key = split(",", self.custom_data)[1]
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "kubectl --kubeconfig=/etc/kubernetes/admin.conf cordon ${self.hostname}",
      "kubectl --kubeconfig=/etc/kubernetes/admin.conf drain ${self.hostname}",
      "kubectl --kubeconfig=/etc/kubernetes/admin.conf delete node ${self.hostname}",
    ]
  }
}

