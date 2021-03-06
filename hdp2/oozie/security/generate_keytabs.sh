{%- from 'krb5/settings.sls' import krb5 with context %}
{%- set realm = krb5.realm -%}
#!/bin/bash
export KRB5_CONFIG={{ pillar.krb5.conf_file }}
(
echo "addprinc -randkey oozie/{{ grains.fqdn }}@{{ realm }}"
echo "xst -k oozie-unmerged.keytab oozie/{{ grains.fqdn }}@{{ realm }}"
) | kadmin -p kadmin/admin -kt /root/admin.keytab

(
echo "rkt oozie-unmerged.keytab"
echo "rkt /root/HTTP.keytab"
echo "wkt oozie.keytab"
) | ktutil

rm -rf oozie-unmerged.keytab
chown oozie:oozie oozie.keytab
chmod 400 *.keytab
