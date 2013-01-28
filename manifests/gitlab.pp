class gitlab::gitlab(
    $db_username,
    $db_password,
) {
    vcsrepo { 'gitlab':
        ensure      => present,
        path        => '/home/gitlab/gitlab',
        provider    => git,
        source      => 'https://github.com/gitlabhq/gitlabhq.git',
        revision    => '4-1-stable',
        owner       => 'gitlab',
        group       => 'gitlab',
        require     => User['gitlab'],
    }

    file { 'gitlab.yml':
        path        => '/home/gitlab/gitlab/config/gitlab.yml',
        ensure      => file,
        owner       => 'gitlab',
        group       => 'gitlab',
        content     => template('gitlab/gitlab.yml.erb'),
    }

    file { 'database.yml':
        path        => '/home/gitlab/gitlab/config/database.yml',
        ensure      => file,
        owner       => 'gitlab',
        group       => 'gitlab',
        content     => template('gitlab/database.yml.erb'),
    }

    if !defined(Package['mysql-devel']) {
        package {'mysql-devel':
            ensure  => installed,
        }
    }

    if !defined(Package['libicu-devel']) {
        package { 'libicu-devel':
            ensure      => installed,
        }
    }

    package { 'charlock_holmes':
        ensure      => installed,
        provider    => gem,
        require     => Package['libicu-devel'],
    }

    exec { 'bundle-install':
        command     => '/usr/local/rvm/gems/ruby-1.9.3-p374@global/bin/bundle install --deployment --without development test postgres',
        cwd         => '/home/gitlab/gitlab',
        user        => 'gitlab',
        require     => [
            Class['gitlab::ruby'], 
            Vcsrepo['gitlab'], 
            Package['charlock_holmes'], 
            Package['mysql-devel'],
            File['gitlab.yml'],
        ],
        logoutput   => on_failure,
        creates     => '/home/gitlab/gitlab/.bundle/config',
    }

    file { '/home/git/.gitolite/hooks/common/post-receive':
        ensure      => file,
        owner       => 'git',
        group       => 'git',
        source      => '/home/gitlab/gitlab/lib/hooks/post-receive',
        require     => [
            User['git'],
            Vcsrepo['gitlab'],
        ],
    }

    exec { '/usr/local/rvm/gems/ruby-1.9.3-p374@global/bin/bundle exec rake gitlab:setup RAILS_ENV=production':
        cwd         => '/home/gitlab/gitlab',
        user        => 'gitlab',
        refreshonly => true,
        subscribe   => [
            User['gitlab'],
            File['database.yml'],
        ],
        logoutput   => on_failure,
        require     => [
            Class['gitlab::ruby'], 
            Vcsrepo['gitlab'],
            Exec['bundle-install'],
        ],
    }
}