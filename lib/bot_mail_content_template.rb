FROM_ADDRESS = 'mycloud@zyxel.com.tw'

OFFLINE_SUBJECT = 'ZyXEL DDNS Offline Alert'
OFFLINE_MESSAGE = 'ZyXEL DDNS server is currently offline temporarily and we apologize for the inconvenience.'

ONLINE_SUBJECT = 'ZyXEL DDNS Online Alert'
ONLINE_MESSAGE = 'ZyXEL DDNS server has return online. Again, we apologize for the inconvenience.'

MAIL_CONTENT = <<EOT
From: %s
To: undisclosed-recipients:;
Bcc: %s
Subject: %s

%s
EOT