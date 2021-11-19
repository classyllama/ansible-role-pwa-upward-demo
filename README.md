# Ansible Role: PWA Upward Demo

Installs a shell script on RHEL / CentOS for installing PWA (Venia theme).

The role sets up a config file for a specific domain/directory/user and saves the config files and scripts in the user's home directory ~/username/pwa-upward-demo/.

Please note, PWA Studio Version must be compatible with the installed Magento version, please check the requested PWA Studio version using [PWA Studio compability matrix](https://magento.github.io/pwa-studio/technologies/magento-compatibility/).

## Requirements

NodeJS must be installed on the server. See meta/main.yml for dependencies..

## Role Variables

See `defaults/main.yml` for details.

## Dependencies

None.

## Example Playbook

    - hosts: web
      vars:
        use_classyllama_pwa_upward_demo: true
        pwa_demo_upward_studio_version: 12.1.0
        pwa_demo_upward_scripts_dir: "/home/www-data/pwa-demo-upward"
        pwa_demo_upward_config_name: "site"
        pwa_demo_upward_user: "www-data"
        pwa_demo_upward_group: "www-data"
        pwa_demo_upward_magento_root_dir: "/var/www/data/magento"
        pwa_demo_upward_env_root_dir: "/var/www/data"
        pwa_demo_pwa_studio_compat_matrix_url: "https://raw.githubusercontent.com/magento/pwa-studio/develop/magento-compatibility.js"
        pwa_demo_pwa_studio_download_url: "https://github.com/magento/pwa-studio/archive/refs/tags/"

      roles:
        - { role: classyllama.pwa-upward-demo, tags: pwa-upward-demo, when: use_classyllama_pwa_upward_demo | default(false) }

## Script Usage

    # Once the scripts are on the server
    ~/pwa-demo-upward/install-pwa.sh config_site.json
    ~/pwa-demo-upward/uninstall-pwa.sh config_site.json

## License

This work is licensed under the MIT license. See LICENSE file for details.
