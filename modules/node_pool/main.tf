data "template_file" "node" {
  template = file("${path.module}/node.tpl")

  vars = {
    kube_token      = var.kube_token
    primary_node_ip = var.controller_address
    kube_version    = var.kubernetes_version
    storage         = var.storage
  }
}

resource "metal_device" "x86_node" {
  hostname         = format("${var.cluster_name}-x86-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_x86
  plan             = var.plan_x86
  facilities       = [var.facility]
  user_data        = data.template_file.node.rendered
  custom_data      = "${var.controller_address},${var.ssh_private_key_path}"
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-x86"]

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

resource "metal_device" "arm_node" {
  hostname         = format("${var.cluster_name}-arm-${var.pool_label}-%02d", count.index)
  operating_system = "ubuntu_18_04"
  count            = var.count_arm
  plan             = var.plan_arm
  facilities       = [var.facility]
  user_data        = data.template_file.node.rendered
  custom_data      = "${var.controller_address},${var.ssh_private_key_path}"
  tags             = ["kubernetes", "pool-${var.cluster_name}-${var.pool_label}-arm"]

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
