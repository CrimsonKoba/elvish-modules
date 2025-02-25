  # DO NOT EDIT THIS FILE DIRECTLY
  # This is a file generated from a literate programing source file located at
  # https://github.com/zzamboni/elvish-modules/blob/master/nix.org.
  # You should make any changes there and regenerate it from Emacs org-mode using C-c C-v t

  use re
  use str
  use github.com/CrimsonKoba/elvish-modules/util

  fn multi-user-setup {
    # Set up secure multi-user builds: non-root users build through the
    # Nix daemon.
    if (or (not-eq $E:USER root) (not ?(test -w /nix/var/nix/db))) {
      set E:NIX_REMOTE = daemon
    }

    set E:NIX_USER_PROFILE_DIR = "/nix/var/nix/profiles/per-user/"$E:USER
    var nix-profiles = [
      "/nix/var/nix/profiles/default"
      $E:HOME"/.nix-profile"
    ]
    set E:NIX_PROFILES = (str:join " " $nix-profiles)

    # Set up the per-user profile.
    mkdir -m 0755 -p $E:NIX_USER_PROFILE_DIR
    if (not ?(test -O $E:NIX_USER_PROFILE_DIR)) {
      echo (styled "WARNING: bad ownership on "$E:NIX_USER_PROFILE_DIR yellow) >&2
    }

    if ?(test -w $E:HOME) {
      if (not ?(test -L $E:HOME/.nix-profile)) {
        if (not-eq $E:USER root) {
          ln -s $E:NIX_USER_PROFILE_DIR/profile $E:HOME/.nix-profile
        } else {
          # Root installs in the system-wide profile by default.
          ln -s /nix/var/nix/profiles/default $E:HOME/.nix-profile
        }
      }

      # Subscribe the root user to the NixOS channel by default.
      if (and (eq $E:USER root) (not ?(test -e $E:HOME/.nix-channels))) {
        echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > $E:HOME/.nix-channels
      }

      # Create the per-user garbage collector roots directory.
      var nix-user-gcroots-dir = "/nix/var/nix/gcroots/per-user/"$E:USER
      mkdir -m 0755 -p $nix-user-gcroots-dir
      if (not ?(test -O $nix-user-gcroots-dir)) {
        echo (styled "WARNING: bad ownership on "$nix-user-gcroots-dir yellow) >&2
      }

      # Set up a default Nix expression from which to install stuff.
      if (or (not ?(test -e $E:HOME/.nix-defexpr)) ?(test -L $E:HOME/.nix-defexpr)) {
        rm -f $E:HOME/.nix-defexpr
        mkdir -p $E:HOME/.nix-defexpr
        if (not-eq $E:USER root) {
          ln -s /nix/var/nix/profiles/per-user/root/channels $E:HOME/.nix-defexpr/channels_root
        }
      }
    }

    set E:NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt"
    set E:NIX_PATH = "/nix/var/nix/profiles/per-user/root/channels"
    # E:MANPATH = ~/.nix-profile/share/man
    set paths = [
      ~/.nix-profile/bin
      ~/.nix-profile/sbin
      ~/.nix-profile/lib/kde4/libexec
      /nix/var/nix/profiles/default/bin
      /nix/var/nix/profiles/default/sbin
      /nix/var/nix/profiles/default/lib/kde4/libexec
      $@paths
    ]

    #echo (styled "Nix environment ready" green)
  }

  fn single-user-setup {
    # Set up single-user Nix (no daemon)
    if (not-eq $E:HOME "") {
      var nix-link = ~/.nix-profile
      if (not ?(test -L $nix-link)) {
        echo (styled "creating "$nix-link green) >&2
        var -nix-def-link = /nix/var/nix/profiles/default
        ln -s $-nix-def-link $nix-link
      }
      set paths = [
        $nix-link"/bin"
        $nix-link"/sbin"
        $@paths
      ]
      # Subscribe the user to the Nixpkgs channel by default.
      if (not ?(test -e ~/.nix-channels)) {
        echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > ~/.nix-channels
      }
      # Append ~/.nix-defexpr/channels/nixpkgs to $NIX_PATH so that
      # <nixpkgs> paths work when the user has fetched the Nixpkgs
      # channel.
      if (not-eq $E:NIX_PATH "") {
        set E:NIX_PATH = $E:NIX_PATH":nixpkgs="$E:HOME"/.nix-defexpr/channels/nixpkgs"
      } else {
        set E:NIX_PATH = "nixpkgs="$E:HOME"/.nix-defexpr/channels/nixpkgs"
      }

      # Set $NIX_SSL_CERT_FILE so that Nixpkgs applications like curl work.
      if ?(test -e  /etc/ssl/certs/ca-certificates.crt ) { # NixOS, Ubuntu, Debian, Gentoo, Arch
        set E:NIX_SSL_CERT_FILE = /etc/ssl/certs/ca-certificates.crt
      } elif ?(test -e  /etc/ssl/ca-bundle.pem ) { # openSUSE Tumbleweed
        set E:NIX_SSL_CERT_FILE = /etc/ssl/ca-bundle.pem
      } elif ?(test -e  /etc/ssl/certs/ca-bundle.crt ) { # Old NixOS
        set E:NIX_SSL_CERT_FILE = /etc/ssl/certs/ca-bundle.crt
      } elif ?(test -e  /etc/pki/tls/certs/ca-bundle.crt ) { # Fedora, CentOS
        set E:NIX_SSL_CERT_FILE = /etc/pki/tls/certs/ca-bundle.crt
      } elif ?(test -e  $nix-link"/etc/ssl/certs/ca-bundle.crt" ) { # fall back to cacert in Nix profile
        set E:NIX_SSL_CERT_FILE = $nix-link"/etc/ssl/certs/ca-bundle.crt"
      } elif ?(test -e  $nix-link"/etc/ca-bundle.crt" ) { # old cacert in Nix profile
        set E:NIX_SSL_CERT_FILE = $nix-link"/etc/ca-bundle.crt"
      }
    }
  }

  fn search {|@pkgs|
    var pipecmd = cat
    var opts = []
    if (eq $pkgs[0] "--json") {
      set pipecmd = json_pp
    }
    nix-env -qa $@opts $@pkgs | $pipecmd
  }

  fn install {|@pkgs|
    nix-env -i $@pkgs
  }

  fn brew-to-nix {
    brew leaves | each {|pkg|
      echo (styled "Package "$pkg green)
      brew info $pkg
      var loop = $true
      while $loop {
        set loop = $false
        print (styled $pkg": [R]emove/[Q]uery nix/[K]eep/Remove and [I]nstall with nix? " yellow)
        var resp = (util:readline </dev/tty)
        if (eq $resp "r") {
          brew uninstall --force $pkg
        } elif (eq $resp "q") {
          set _ = ?(search --description '.*'$pkg'.*')
          set loop = $true
        } elif (eq $resp "i") {
          install $pkg
          brew uninstall --force $pkg
        }
      }
    }
  }

  fn info {|pkg|
    # Get data
    var install-path = nil
    var installed = ?(set install-path = [(re:split '\s+' (nix-env -q --out-path $pkg 2>/dev/null))][1])
    var flag = (if $installed { put "-q" } else { put "-qa" })
    var data = (nix-env $flag --json $pkg | from-json)
    var top-key = (keys $data | take 1)
    set pkg = $data[$top-key]
    var meta = $pkg[meta]

    # Produce the output
    print (styled $pkg[name] yellow)
    if (has-key $meta description) {
      echo ":" $meta[description]
    } else {
      echo ""
    }
    if (has-key $meta homepage) {
      echo (styled "Homepage: " blue) $meta[homepage]
    }
    if $installed {
      echo (styled "Installed:" green) $install-path
    } else {
      echo (styled "Not installed" red)
    }
    echo From: (re:replace ':\d+' "" $meta[position])
    if (has-key $meta longDescription) {
      echo ""
      echo $meta[longDescription] | fmt
    }
  }
