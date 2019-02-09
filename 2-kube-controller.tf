data "template_file" "controller" {
  template = "${file("${path.module}/controller.tpl")}"

  vars {
    kube_token          = "${random_string.kube_init_token_a.result}.${random_string.kube_init_token_b.result}"
    packet_network_cidr = "${cidrhost(packet_reserved_ip_block.kubernetes.cidr_notation,0)}"
    kube_version        = "${var.kubernetes_version}"
    secrets_encryption  = "${var.secrets_encryption}"
  }
}

resource "packet_device" "k8s_primary" {
  hostname         = "${var.cluster_name}-controller"
  operating_system = "ubuntu_16_04"
  plan             = "${var.plan_primary}"
  facility         = "${var.facility}"
  user_data        = "${data.template_file.controller.rendered}"

  billing_cycle = "hourly"
  project_id    = "${packet_project.kubernetes_multiarch.id}"
}

resource "packet_ip_attachment" "kubernetes_lb_block" {
  device_id     = "${packet_device.k8s_primary.id}"
  cidr_notation = "${packet_reserved_ip_block.kubernetes.cidr_notation}"
}
