#!/bin/bash

deploy () {
    echo "Runing deploy function"
    test -d $APP_NAME || (git clone --quiet --branch=$WORDPRESS_VERSION --single-branch https://github.com/WordPress/WordPress.git $APP_NAME && cd $APP_NAME && git checkout -qb master)
    test -f $APP_NAME/wp-config.php || (cp config/wp-config.php $APP_NAME/wp-config.php && cd $APP_NAME && git add wp-config.php && git commit -qm "Adding environment-variable based wp-config.php")
    test -f $APP_NAME/.buildpacks   || (echo "https://github.com/heroku/heroku-buildpack-php.git#$BUILDPACK_VERSION" > $APP_NAME/.buildpacks && cd $APP_NAME && git add .buildpacks && git commit -qm "Forcing php buildpack usage")
    test -f $APP_NAME/composer.json || (cp config/composer.json $APP_NAME/composer.json && cp config/composer.lock $APP_NAME/composer.lock && cd $APP_NAME && git add composer.json composer.lock && git commit -qm "Use PHP and the mysql extension")
    cd $APP_NAME && (git remote rm dokku 2> /dev/null || true) && git remote add dokku "dokku@localhost:$APP_NAME"
    cd ..
    curl -so tmp/wp-salts https://api.wordpress.org/secret-key/1.1/salt/
    chmod +x tmp/wp-salts
    sed -i.bak -e 's/ //g' -e "s/);//g" -e "s/define('/dokku config:set $APP_NAME /g" -e "s/SALT',/SALT=/g" -e "s/KEY',[ ]*/KEY=/g" ./tmp/wp-salts && rm ./tmp/wp-salts.bak

    rsync -rzvh /root/project/source/web/app/mu-plugins /root/project/$APP_NAME/wp-content/
    rsync -rzvh /root/project/source/web/app/plugins /root/project/$APP_NAME/wp-content/
    rsync -rzvh /root/project/source/web/app/themes /root/project/$APP_NAME/wp-content/

    dokku apps:create $APP_NAME
    mkdir -p /var/lib/dokku/data/storage/$APP_NAME-uploads
    chown 32767:32767 /var/lib/dokku/data/storage/$APP_NAME-uploads
    dokku storage:mount $APP_NAME /var/lib/dokku/data/storage/$APP_NAME-uploads:/app/wp-content/uploads

    dokku mysql:create $APP_NAME-database
    dokku mysql:link $APP_NAME-database $APP_NAME
    ./tmp/wp-salts

    cd $APP_NAME
    git add .
    git commit . -m "Sync template vs project"
    git push dokku master

    rm -rf /root/project/source/*
}

update () {
    echo "Runing update function"
    rsync -rzvh /root/project/source/web/app/mu-plugins /root/project/$APP_NAME/wp-content/
    rsync -rzvh /root/project/source/web/app/plugins /root/project/$APP_NAME/wp-content/
    rsync -rzvh /root/project/source/web/app/themes /root/project/$APP_NAME/wp-content/
    cd $APP_NAME
    git add .
    git commit . -m "Update project"
    git push dokku master

    rm -rf /root/project/source/*
}

if dokku apps:exists "$APP_NAME"
then update
else deploy
fi
