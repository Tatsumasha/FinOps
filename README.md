# FinOps

Este repositorio contiene la configuración de Terraform para desplegar infraestructura en Google Cloud Platform (GCP).

## Prerrequisitos

Antes de empezar, asegúrate de tener instalados los siguientes componentes en tu máquina local:

- [Terraform](https://www.terraform.io/downloads.html) (versión 1.0 o superior)
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (gcloud)
- Credenciales de acceso a tu proyecto de GCP (puedes configurar esto utilizando `gcloud auth application-default login`).

## Configuración

**Clonar el Repositorio**

   Clona este repositorio en tu máquina local:

   ```sh
   git clone https://github.com/Tatsumasha/FinOps.git
   cd tu-repo-terraform
   ```

### Running

Para desplegar la infraestructura

1. Situate en el directorio raiz.
1. Ejecuta el fichero export_functions.sh

```bash
chmod 700 export_functions.sh
./export_functions.sh
```

* Inicializa la configuracion de terraform

```bash
terraform init
```

* Applica la configuracion seleccionada

```bash
terraform apply -var-file var_values.tfvars
```

* Destruye toda la infraestructura

```bash
terraform destroy -var-file var_values.tfvars
```