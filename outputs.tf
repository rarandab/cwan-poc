output "instances" {
  value = { for item in flatten([
    for c, c_d in module.compute : [
      for i, ic in c_d.instances_created : {
        c  = c
        i  = i
        id = ic.id
        ip = ic.private_ip
      }
    ]
    ]) : "${item.c}${item.i}" => item.ip
  }
}
