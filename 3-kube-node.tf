data "template_file" "node" {
  template = "${file("${path.module}/node.tpl")}"

  vars {
    kube_token      = "${random_string.kube_init_token_a.result}.${random_string.kube_init_token_b.result}"
    primary_node_ip = "${packet_device.k8s_primary.network.0.address}"
    kube_version    = "${var.kubernetes_version}"
  }
}

resource "packet_device" "x86_node" {
  hostname         = "${format("${var.cluster_name}-x86-node-%02d", count.index)}"
  operating_system = "ubuntu_16_04"
  count            = "${var.count_x86}"
  plan             = "${var.plan_x86}"
  facility         = "${var.facility}"
  user_data        = "${data.template_file.node.rendered}"

  billing_cycle = "hourly"
  project_id    = "${packet_project.kubernetes_multiarch.id}"
}

resource "packet_device" "arm_node" {
  hostname         = "${format("${var.cluster_name}-arm-node-%02d", count.index)}"
  operating_system = "ubuntu_16_04"
  count            = "${var.count_arm}"
  plan             = "${var.plan_arm}"
  facility         = "${var.facility}"
  user_data        = "${data.template_file.node.rendered}"

  billing_cycle = "hourly"
  project_id    = "${packet_project.kubernetes_multiarch.id}"
}
