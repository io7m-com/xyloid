#!/bin/sh

rsync \
  --delete \
  -a \
  -zz \
  -c \
  -L \
  --chmod=ugo-rwx,Dugo+x,ugo+r,u+w \
  --progress \
  site-out/ \
  www2-int.io7m.com:/var/storage/www/www.io7m.com/software/xyloid/

