class StorageMonitor < Formula
  desc "Linux/macOS disk, inode, storage-growth monitoring and migration verification toolkit"
  homepage "https://github.com/YOUR_GH_USER/storage-monitor"
  url "https://github.com/YOUR_GH_USER/storage-monitor/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PUT_SHA256_HERE"   # generate with: shasum -a 256 v1.0.0.tar.gz
  license "MIT"

  depends_on "coreutils"

  def install
    libexec.install Dir["bin/*"], Dir["lib/*"], Dir["conf/*"]
    (libexec/"bin").install Dir["bin/*.sh"] rescue nil

    # Lay out the same structure install.sh expects, under Homebrew's prefix
    (libexec/"bin").mkpath
    (libexec/"lib").mkpath
    (libexec/"conf").mkpath
    (libexec/"data").mkpath
    (libexec/"logs").mkpath
    (libexec/"reports").mkpath

    cp_r "bin/.", libexec/"bin"
    cp_r "lib/.", libexec/"lib"
    cp_r "conf/.", libexec/"conf"

    chmod 0755, Dir[libexec/"bin/*.sh"]

    %w[storage-monitor growth-tracker generate-report migration-verify].each do |script|
      (bin/script).write <<~EOS
        #!/usr/bin/env bash
        exec "#{libexec}/bin/#{script}.sh" "$@"
      EOS
      chmod 0755, bin/script
    end
  end

  def caveats
    <<~EOS
      Config file:      #{libexec}/conf/storage-monitor.conf
      Logs/reports/data: #{libexec}/{logs,reports,data}

      Get started:
        storage-monitor
        growth-tracker snapshot
        generate-report
    EOS
  end

  test do
    system "#{bin}/storage-monitor", "--json"
  end
end
