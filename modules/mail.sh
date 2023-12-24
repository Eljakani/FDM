#!/bin/bash

setup_dns() {
    # install bind9
    apt-get install bind9 -y
    # create a backup of the original file
    cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak
    # create a new file
    touch /etc/bind/named.conf.local
    # get ip address
    ip=$(hostname -I | awk '{print $1}')
    hostname=$(hostname)
    # ask for domain name with example suggestion hostname
    domain=$(whiptail --inputbox "Enter domain name" 8 78 "$hostname" --title "Domain Name" 3>&1 1>&2 2>&3)
    # set the domain name
    echo "zone \"$domain\" {" >> /etc/bind/named.conf.local
    echo "        type master;" >> /etc/bind/named.conf.local
    echo "        file \"/etc/bind/db.$domain\";" >> /etc/bind/named.conf.local
    echo "};" >> /etc/bind/named.conf.local
    # create a new file
    touch /etc/bind/db.$domain
    # ask for mail server name with example suggestion mail.$domain
    echo "\$TTL    604800" >> /etc/bind/db.$domain
    echo "@       IN      SOA     $domain. root.$domain. (" >> /etc/bind/db.$domain
    echo "                              2         ; Serial" >> /etc/bind/db.$domain
    echo "                         604800         ; Refresh" >> /etc/bind/db.$domain
    echo "                          86400         ; Retry" >> /etc/bind/db.$domain
    echo "                        2419200         ; Expire" >> /etc/bind/db.$domain
    echo "                         604800 )       ; Negative Cache TTL" >> /etc/bind/db.$domain
    echo ";" >> /etc/bind/db.$domain
    echo "@       IN      NS      $domain." >> /etc/bind/db.$domain
    echo "@       IN      A       $ip" >> /etc/bind/db.$domain
    echo "mail    IN      A       $ip" >> /etc/bind/db.$domain
    echo "www     IN      A       $ip" >> /etc/bind/db.$domain
        # restart bind9
        systemctl restart bind9
        # set the hostname
        hostnamectl set-hostname $domain
        # set the domain name
        echo "$domain" > /etc/hostname
        # restart bind9
        systemctl restart bind9
    }
    install_mail() {
        # install postfix
        apt-get install postfix -y
        # install dovecot
        apt-get install dovecot-core dovecot-imapd dovecot-pop3d -y
        # install mailutils
        apt-get install mailutils -y
        # install smtp server
        apt-get install sasl2-bin -y

    }
    generate_ssl() {
        echo "Generating SSL certificate ..."
        country=$(whiptail --inputbox "Enter country name" 8 78 "MA" --title "Country Name" 3>&1 1>&2 2>&3)
        city=$(whiptail --inputbox "Enter city" 8 78 "MARRAKESH" --title "City" 3>&1 1>&2 2>&3)
        organization=$(whiptail --inputbox "Organization Name" 8 78 "ENSA-M" --title "Organization Name" 3>&1 1>&2 2>&3)
        organizational_unit=$(whiptail --inputbox "Organizational Unit" 8 78 "GCDSTE" --title "Organizational Unit" 3>&1 1>&2 2>&3)
        common_name="$domain"
        email="admin@$domain"
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/ssl-cert-snakeoil.key -out /etc/ssl/certs/ssl-cert-snakeoil.pem -subj "/C=$country/ST=$city/L=$city/O=$organization/OU=$organizational_unit/CN=$common_name/emailAddress=$email"
        whiptail --title "SSL Certificate" --msgbox "SSL certificate was generated and saved in /etc/ssl/certs/ssl-cert-snakeoil.pem" 8 78

    }
    configure_mail() {
        cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
        touch /etc/postfix/main.cf
        echo "myhostname = $domain" >> /etc/postfix/main.cf
        echo "mydomain = $domain" >> /etc/postfix/main.cf
        echo "myorigin = $domain" >> /etc/postfix/main.cf
        echo "inet_interfaces = all" >> /etc/postfix/main.cf
        echo "mydestination = $domain, localhost.$domain, localhost, $hostname" >> /etc/postfix/main.cf
        echo "mynetworks =  $ip/24 " >> /etc/postfix/main.cf
        echo "home_mailbox = Maildir/" >> /etc/postfix/main.cf
        echo "smtpd_banner = $hostname ESMTP" >> /etc/postfix/main.cf
        echo "alias_maps = hash:/etc/aliases" >> /etc/postfix/main.cf
        echo "alias_database = hash:/etc/aliases" >> /etc/postfix/main.cf
        echo "smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination" >> /etc/postfix/main.cf
        echo "mailbox_size_limit = 0" >> /etc/postfix/main.cf
        echo "recipient_delimiter = +" >> /etc/postfix/main.cf
        echo "smtpd_sasl_type = dovecot" >> /etc/postfix/main.cf
        echo "smtpd_sasl_path = private/auth" >> /etc/postfix/main.cf
        echo "smtpd_sasl_auth_enable = yes" >> /etc/postfix/main.cf
        echo "smtpd_sasl_security_options = noanonymous" >> /etc/postfix/main.cf
        echo "smtpd_sasl_local_domain = $domain" >> /etc/postfix/main.cf
        echo "smtpd_recipient_restrictions = permit_mynetworks,permit_auth_destination,permit_sasl_authenticated,reject" >> /etc/postfix/main.cf
        echo "smtpd_tls_security_level = may" >> /etc/postfix/main.cf
        echo "smtpd_tls_auth_only = yes" >> /etc/postfix/main.cf
        echo "smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache" >> /etc/postfix/main.cf
        echo "smtpd_tls_received_header = yes" >> /etc/postfix/main.cf
        echo "smtpd_tls_session_cache_timeout = 3600s" >> /etc/postfix/main.cf
        echo "tls_random_source = dev:/dev/urandom" >> /etc/postfix/main.cf
        echo "smtp_tls_security_level = may" >> /etc/postfix/main.cf
        echo "smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache" >> /etc/postfix/main.cf
        echo "smtp_tls_session_cache_timeout = 3600s" >> /etc/postfix/main.cf
        echo "smtp_use_tls = yes" >> /etc/postfix/main.cf
        echo "smtp_tls_note_starttls_offer = yes" >> /etc/postfix/main.cf
        echo "smtpd_tls_CAfile = /etc/ssl/certs/ssl-cert-snakeoil.pem" >> /etc/postfix/main.cf
        echo "ssl_cert = </etc/ssl/certs/ssl-cert-snakeoil.pem" >> /etc/dovecot/conf.d/10-ssl.conf
        echo "ssl_key = </etc/ssl/private/ssl-cert-snakeoil.key" >> /etc/dovecot/conf.d/10-ssl.conf
        echo "smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem" >> /etc/postfix/main.cf
        echo "smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key" >> /etc/postfix/main.cf
        
        whiptail --title "Postfix Configuration" --msgbox "Postfix was configured successfully\n\nThe configuration file is located in /etc/postfix/main.cf" 15 60
    }
    setup_mail() {
        systemctl reload postfix
        systemctl restart postfix
        systemctl restart dovecot
    }
    setup_mail_user() {
        # ask for username
        username=admin
        # use a random password
        password=$(openssl rand -base64 12)
        # create user
        useradd -m $username
        # set password
        echo "$username:$password" | chpasswd
        # create a backup of the original file
        cp /etc/dovecot/conf.d/10-mail.conf /etc/dovecot/conf.d/10-mail.conf.bak
        # create a new file
        touch /etc/dovecot/conf.d/10-mail.conf
        # set the mail location
        echo "mail_location = maildir:~/Maildir" >> /etc/dovecot/conf.d/10-mail.conf
        # create a backup of the original file
        cp /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.bak
        # create a new file
        touch /etc/dovecot/conf.d/10-auth.conf
        # set the authentication mechanism
        echo "disable_plaintext_auth = no" >> /etc/dovecot/conf.d/10-auth.conf
        # create a backup of the original file
        cp /etc/dovecot/conf.d/10-master.conf /etc/dovecot/conf.d/10-master.conf.bak
        # create a new file
        touch /etc/dovecot/conf.d/10-master.conf
        # set the authentication mechanism
        echo "service auth {" >> /etc/dovecot/conf.d/10-master.conf
        echo "  unix_listener /var/spool/postfix/private/auth {" >> /etc/dovecot/conf.d/10-master.conf
        echo "    mode = 0666" >> /etc/dovecot/conf.d/10-master.conf
        echo "  }" >> /etc/dovecot/conf.d/10-master.conf
        echo "}" >> /etc/dovecot/conf.d/10-master.conf
        # restart postfix
        systemctl restart postfix
        # restart dovecot
        systemctl restart dovecot
        # show username and password
        whiptail --title "Mail User" --msgbox "The admin user was created successfully\n\nUsername: $username\nPassword: $password" 12 60
    }
    remove_everything() {
        # remove postfix
        apt-get remove postfix -y
        # remove dovecot
        apt-get remove dovecot-core dovecot-imapd dovecot-pop3d -y
        # remove mailutils
        apt-get remove mailutils -y
        # remove bind9
        apt-get remove bind9 -y
        # remove ssl-cert
        apt-get remove ssl-cert -y
        # remove the configuration files
        rm -rf /etc/bind/named.conf.local
        rm -rf /etc/bind/db.*
        rm -rf /etc/postfix/main.cf
        rm -rf /etc/dovecot/conf.d/10-mail.conf
        rm -rf /etc/dovecot/conf.d/10-auth.conf
        rm -rf /etc/dovecot/conf.d/10-master.conf
        # remove the backup files
        rm -rf /etc/bind/named.conf.local.bak
        rm -rf /etc/postfix/main.cf.bak
        rm -rf /etc/dovecot/conf.d/10-mail.conf.bak
        rm -rf /etc/dovecot/conf.d/10-auth.conf.bak
        rm -rf /etc/dovecot/conf.d/10-master.conf.bak
        # remove the ssl certificate
        rm -rf /etc/ssl/certs/ssl-cert-snakeoil.pem
        rm -rf /etc/ssl/private/ssl-cert-snakeoil.key
        # remove the mail user prompt
        whiptail --title "Mail User" --yesno "Do you want to remove the admin user?" 8 78
        if [ $? -eq 0 ]; then
            # remove the user
            userdel -r $username
            # remove the user's home directory
            rm -rf /home/$username
            # remove the user's mail directory
            rm -rf /var/mail/$username

        fi


    }
    check_if_already_installed() {
        if [ -f /etc/postfix/main.cf ] && [ -f /etc/dovecot/conf.d/10-mail.conf ] && [ -f /etc/dovecot/conf.d/10-auth.conf ] && [ -f /etc/dovecot/conf.d/10-master.conf ]; then
            return 0
        else
            return 1
        fi
    }

    send_greetings_email_to_everyone() {
        # send greetings email to everyone in the server
        users=$(cat /etc/passwd | grep /home | cut -d ":" -f 1)
        for user in $users; do
            # send email as admin to everyone
            echo "Hello $user, this is an email sent from $domain" | mail -s "Greetings from $domain" $user@$domain
        done
    }
    setup_cron_job_to_greet_every_new_user() {
        whiptail --title "Mail Server" --yesno "Do you want to setup a cron job to greet every new user?" 8 78
        if [ $? -eq 0 ]; then
            # create a backup of the original file
            cp /etc/crontab /etc/crontab.bak
            # create a new file
            touch /etc/crontab
            # set the cron job
            echo "0 0 * * * root /root/greet.sh" >> /etc/crontab
            # create a new file
            touch /root/greet.sh
            # set the cron job
            echo "#!/bin/bash" >> /root/greet.sh
            echo "users=\$(cat /etc/passwd | grep /home | cut -d \":\" -f 1)" >> /root/greet.sh
            echo "for user in \$users; do" >> /root/greet.sh
            echo "    # send email as admin to everyone" >> /root/greet.sh
            echo "    echo \"Hello \$user, this is an email sent from $domain\" | mail -s \"Greetings from $domain\" \$user@$domain" >> /root/greet.sh
            echo "done" >> /root/greet.sh
            # make the script executable
            chmod +x /root/greet.sh
            # restart cron service
            systemctl restart cron
        fi
    }


    # Main script
    if check_if_already_installed; then
        whiptail --title "Mail Server" --yesno "Mail server is already installed on your system\n\nDo you want to reinstall it or quit?" 12 60 --yes-button "Reinstall" --no-button "Quit"
        if [ $? -eq 0 ]; then
            remove_everything
            whiptail --title "Mail Server" --msgbox "Mail server was removed successfully and will be reinstalled" 8 78
        else
            exit 0
        fi
    fi
    setup_dns
    install_mail
    generate_ssl
    configure_mail
    setup_mail
    setup_mail_user
    setup_cron_job_to_greet_every_new_user
    send_greetings_email_to_everyone
    whiptail --title "Mail Server" --msgbox "Mail server was configured successfully" 8 78
