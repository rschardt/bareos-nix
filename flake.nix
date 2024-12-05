{
  description = "Flake for bareos";

  inputs = {
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        stdenv = pkgs.stdenv;
      in
      {
        packages = with pkgs.lib; with stdenv; with pkgs; rec {
          default = bareos-client-pkg;

          # TODO There is a systemd file in the lib which makes it easy to nixify this as a service
          bareos-client-lib = stdenv.mkDerivation {
            name = "bareos-client-lib";
            version = "23.1.1";

            src = pkgs.fetchurl {
              url = "https://download.bareos.org/current/ULC_deb_OpenSSL_3.0/amd64/bareos-universal-client_23.1.1~pre3.47aeb30a1-149_amd64.deb";
              hash = "sha256-I3/K9CqP2YsWXva4F2SDW5pU9vd2SlIbNAAE1QOYcJM=";
            };

            buildInputs = with pkgs; [ dpkg ];
            unpackPhase = ''
              dpkg -x $src unpacked
              mkdir $out
              cp -r unpacked/* $out/
            '';
          };

          bareos-client-pkg = stdenv.mkDerivation {
            name = "bareos-client-pkg";
            version = "23.1.1";

            src = pkgs.fetchurl {
              url = "https://download.bareos.org/current/ULC_deb_OpenSSL_3.0/amd64/bareos-universal-client_23.1.1~pre3.47aeb30a1-149_amd64.deb";
              hash = "sha256-I3/K9CqP2YsWXva4F2SDW5pU9vd2SlIbNAAE1QOYcJM=";
            };

            nativeBuildInputs = with pkgs; [ acl ];
            buildInputs = with pkgs; [ dpkg openssl libz autoPatchelfHook ];
            unpackPhase = ''
              dpkg -x $src unpacked
              mkdir -p $out/bin $out/lib
              cp -r unpacked/usr/lib/bareos/* $out/lib
              cp -r unpacked/usr/sbin/* $out/bin
            '';
          };

          ### complete bareos - botched -- this is from matthewbauers nixpkgs
          bareos-nix = stdenv.mkDerivation rec {
            name = "bareos-${version}";
            version = "17.2.5";

            src = fetchFromGitHub {
              owner = "bareos";
              repo = "bareos";
              rev = "Release/${version}";
              name = "${name}-src";
              sha256 = "1mgh25lhd05m26sq1sj5ir2b4n7560x93ib25cvf9vmmypm1c7pn";
            };

            nativeBuildInputs = [ rpcsvc-proto pkg-config ];
            buildInputs = [
              nettools gettext readline openssl python2 flex ncurses sqlite postgresql
              #mysql.connector-c zlib lzo jansson acl glusterfs libceph libcap rocksdb
              zlib lzo jansson acl glusterfs libceph libcap rocksdb
              rpcsvc-proto
            ];

            #postPatch = ''
            #    sed -i 's,\(-I${withGlusterfs}/include\),\1/glusterfs,' configure
            #      '';

            configureFlags = [
              "--sysconfdir=/etc"
              "--exec-prefix=\${out}"
              "--enable-lockmgr"
              "--enable-dynamic-storage-backends"
              "--with-basename=nixos" # For reproducible builds since it uses the hostname otherwise
              "--with-hostname=nixos" # For reproducible builds since it uses the hostname otherwise
              "--with-working-dir=/var/lib/bareos"
              "--with-bsrdir=/var/lib/bareos"
              "--with-logdir=/var/log/bareos"
              "--with-pid-dir=/var/run/bareos"
              "--with-subsys-dir=/var/run/bareos"
              "--enable-ndmp"
              "--enable-lmdb"
              "--enable-batch-insert"
              "--enable-dynamic-cats-backends"
              "--enable-sql-pooling"
              "--enable-scsi-crypto"
            ] ++ optionals (readline != null) [ "--disable-conio" "--enable-readline" "--with-readline=${readline.dev}" ]
            ++ optional (python2 != null) "--with-python=${python2}"
            ++ optional (openssl != null) "--with-openssl=${openssl.dev}"
            ++ optional (sqlite != null) "--with-sqlite3=${sqlite.dev}"
            ++ optional (postgresql != null) "--with-postgresql=${postgresql}"
            #++ optional (mysql != null) "--with-mysql=${mysql.connector-c}"
            ++ optional (zlib != null) "--with-zlib=${zlib.dev}"
            ++ optional (lzo != null) "--with-lzo=${lzo}"
            ++ optional (jansson != null) "--with-jansson=${jansson}"
            ++ optional (acl != null) "--enable-acl"
            ++ optional (glusterfs != null) "--with-glusterfs=${glusterfs}"
            ++ optional (libceph != null) "--with-cephfs=${libceph}";

            installFlags = [
              "sysconfdir=\${out}/etc"
              "confdir=\${out}/etc/bareos"
              "scriptdir=\${out}/etc/bareos"
              "working_dir=\${TMPDIR}"
              "log_dir=\${TMPDIR}"
              "sbindir=\${out}/bin"
            ];

            meta = with lib; {
              homepage = http://www.bareos.org/;
              description = "A fork of the bacula project";
              license = licenses.gpl3;
              platforms = platforms.unix;
              maintainers = with maintainers; [ wkennington ];
            };
          };
        };
      }
    );
}
