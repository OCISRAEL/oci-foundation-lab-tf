resource "oci_load_balancer_load_balancer" "app" {
  compartment_id             = oci_identity_compartment.lab.id
  display_name               = "${local.name_prefix}-lb"
  shape                      = "flexible"
  subnet_ids                 = [oci_core_subnet.public.id]
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.lb.id]
  freeform_tags              = local.common_tags

  shape_details {
    minimum_bandwidth_in_mbps = var.lb_min_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.lb_max_bandwidth_mbps
  }

  depends_on = [oci_core_instance.app]
}

resource "oci_load_balancer_backend_set" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.app.id
  name             = "bs-demo"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "TCP"
    port              = var.lb_health_check_port
    retries           = 3
    interval_ms       = 10000
    timeout_in_millis = 3000
  }
}

resource "oci_load_balancer_backend" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.app.id
  backendset_name  = oci_load_balancer_backend_set.app.name
  ip_address       = oci_core_instance.app.private_ip
  port             = var.app_port
  weight           = 1
  backup           = false
  drain            = false
  offline          = false
}

resource "oci_load_balancer_listener" "app" {
  load_balancer_id         = oci_load_balancer_load_balancer.app.id
  name                     = "lb-listener-${var.app_port}"
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = var.app_port
  protocol                 = "HTTP"
}
