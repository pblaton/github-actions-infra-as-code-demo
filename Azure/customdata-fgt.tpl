Content-Type: multipart/mixed; boundary="===============0086047718136476635=="
MIME-Version: 1.0

--===============0086047718136476635==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="config"

config system sdn-connector
	edit azure
		set type azure
	end
end
config sys global
    set hostname "${fgt_vm_name}"
    set gui-theme mariner
end
config vpn ssl settings
    set port 7443
end
config router static
    edit 1
        set gateway ${fgt_external_gw}
        set device port1
    next
    edit 2
        set dst ${vnet_network}
        set gateway ${fgt_internal_gw}
        set device port2
    next
end
config system probe-response
    set http-probe-value OK
    set mode http-probe
end
config system interface
    edit port1
        set mode static
        set ip ${fgt_external_ipaddr}/${fgt_external_mask}
        set description external
        set allowaccess ping https ssh ftm
    next
    edit port2
        set mode static
        set ip ${fgt_internal_ipaddr}/${fgt_internal_mask}
        set description internal
    next
end
%{ if fgt_ssh_public_key != "" }
config system admin
    edit "${fgt_username}"
        set ssh-public-key1 "${trimspace(file(fgt_ssh_public_key))}"
    next
end
%{ endif }
%{ if fgt_license_flexvm != "" }
exec vm-license ${fgt_license_flexvm}
%{ endif }
config system automation-trigger
    edit "RT-Trigger"
        set event-type event-log
        set logid 53200 53201
        config fields
            edit 1
                set name "cfgobj"
                set value "Backend"
            next
        end
    next
end
config system automation-action
    edit "RT-Action"
        set action-type webhook
        set protocol https
        set uri "${az_token_webhook}"
        set http-body "{\"action\":\"%%log.action%%\", \"addr\":\"%%log.addr%%\"}"
        set port 443
        set headers "ResourceGroupName:${prefix}-RG" "RouteTableName:${prefix}-RT-PROTECTED-A" "RouteNamePrefix:ms" "NextHopIp:${fgt_internal_ipaddr}"
    next
end
config system automation-stitch
    edit "RT-Stitch"
        set trigger "RT-Trigger"
        config actions
            edit 1
                set action "RT-Action"
                set required enable
            next
        end
    next
end

execute reboot

%{ if fgt_license_file != "" }
--===============0086047718136476635==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="${fgt_license_file}"

${file(fgt_license_file)}

%{ endif }

--===============0086047718136476635==--
