# Clone Bitnami Redmine on Windows (Unofficial) [develop]
# target bitnami redmine: 4.1.0
# bitnami redmine: https://bitnami.com/stack/redmine
# please run this script in the C:\Bitnami\redmine-x.x.x-x\apps


require "fileutils"
# require "mysql2"
require "yaml"

module CommonFunctions
  # functions
  def add_version(path)
    i = 1
    path_ext = File.extname(path)
    path_head = File.dirname(path) + "/" + File.basename(path, path_ext)

    loop {
      path_new = path_head + "." + i.to_s + path_ext
      if !File.exist?( path_new )
        FileUtils.cp(path, path_new, preserve:true)
        break
      end
      i += 1
    }
  end

  def check_file(path, flg_add_version=false)
    if !File.exist?(path)
      puts "file not found"
      puts path
      return false
    end
    if flg_add_version
      add_version path
    end
    return true
  end
end

class CloneRedmine
  include CommonFunctions

  def initialize
    redmine_info = Struct.new(:name, :port1, :port2)

    @redmine_source = redmine_info.new(
      "redmine", "3001", "3002"
    )

    # check source
    if !Dir.exist?(@redmine_source.name)
      puts "source directory is not found."
      exit
    end

    @redmine_new = redmine_info.new
    puts "new-redmine's name?"
    @redmine_new.name = gets.chomp


    # check new redmine
    if Dir.exist?(@redmine_new.name)
      puts "new directory is already exist."
      puts
      puts "continue y/[n]?"
      ret = gets.chomp

      if !ret.match(/^[yY]$/)
        puts "exit."
        exit
      end
    end

    puts "new-redmine's port-1?"
    @redmine_new.port1 = gets.chomp
    puts "new-redmine's port-2?"
    @redmine_new.port2 = gets.chomp

    # check prompt
    puts
    puts "-- source --"
    puts @redmine_source

    puts
    puts "-- new --"
    puts @redmine_new

    puts
    puts "continue y/[n]?"
    ret = gets.chomp

    if !ret.match(/^[yY]$/)
      puts "exit."
      exit
    end

    @redmine_new_db = ""

  end

  def update_additional_environment_rb_source
    target_file = "/htdocs/config/additional_environment.rb"

    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0, true)

    File.open(target_file_0, mode = "w"){|fw|
      fw.puts "config.action_controller.relative_url_root = '/#{@redmine_source.name}'"
      fw.puts "config.session_store :cookie_store,"
      fw.puts "    :key => '_redmine_session',"
      fw.puts "    :path => config.action_controller.relative_url_root"
    }
  end

  def update_configuration_yml_source
    target_file = "/htdocs/config/configuration.yml"

    target_file_0 = @redmine_source.name + target_file + ".tmp"
    target_file_1 = @redmine_source.name + target_file
    exit if !check_file(target_file_1, true)

    FileUtils.cp(target_file_1, target_file_0)  # create temp file

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          if line.match(/^\s+autologin_cookie_path:/)
            line = line.sub(/:.*/, "").chomp + ": Redmine::Utils.relative_url_root"
          end
          fw.puts line
        }
      }
    }

    FileUtils.rm(target_file_0)  # remove temp file
  end

  def xcopy
    command = "xcopy "
    command << @redmine_source.name + " "
    command << @redmine_new.name
    command << " /E /I"
    system command
  end

  def clear_plugins
    target_dir = "#{@redmine_new.name}/htdocs/plugins"
    FileUtils.rm_rf target_dir
    FileUtils.mkdir_p target_dir
  end

  def update_bitnami_apps_prefix_conf
    # update "..\apache2\conf\bitnami\bitnami-apps-prefix.conf"
    target_file_1 = "../apache2/conf/bitnami/bitnami-apps-prefix.conf"
    exit if !check_file(target_file_1, true)

    file = File.open(target_file_1, "a")
    file.puts 'Include "' + File.realdirpath(@redmine_new.name + "/conf/httpd-prefix.conf") + '"'
  end

  def update_conf_httpd_app_conf
    target_file = "/conf/httpd-app.conf"
    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0)

    target_file_1 = @redmine_new.name + target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          if line.match(/^<Directory/) || line.match(/^\s*Include\s/)
            line = line.gsub(/\/#{@redmine_source.name}\//, "/" + @redmine_new.name + "/")
          end
          fw.puts line
        }
      }
    }
  end

  def update_conf_httpd_prefix_conf
    target_file = "/conf/httpd-prefix.conf"
    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0)

    target_file_1 = @redmine_new.name + target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          line = line.gsub(/\/#{@redmine_source.name}/, "/" + @redmine_new.name)
          line = line.gsub(/:#{@redmine_source.port1}\//, ":" + @redmine_new.port1 + "/")
          line = line.gsub(/:#{@redmine_source.port2}\//, ":" + @redmine_new.port2 + "/")
          fw.puts line
        }
      }
    }
  end

  def update_conf_httpd_vhosts_conf
    target_file = "/conf/httpd-vhosts.conf"
    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0)

    target_file_1 = @redmine_new.name + target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          line = line.gsub(/\/#{@redmine_source.name}/, "/" + @redmine_new.name)
          line = line.gsub(/:#{@redmine_source.port1}/, ":" + @redmine_new.port1)
          line = line.gsub(/:#{@redmine_source.port2}/, ":" + @redmine_new.port2)
          fw.puts line
        }
      }
    }
  end

  def update_additional_environment_rb
    target_file = "/htdocs/config/additional_environment.rb"

    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0)

    target_file_1 = @redmine_new.name + target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          line = line.gsub(/\/#{@redmine_source.name}/, "/" + @redmine_new.name)
          fw.puts line
        }
      }
    }
  end


  def update_config_database_yml
    target_file = "/htdocs/config/database.yml"

    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0)

    target_file_1 = @redmine_new.name + target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          if line.match(/database:/)
            line = line.gsub(/_#{@redmine_source.name}/, "_" + @redmine_new.name)
          end
          fw.puts line
        }
      }
    }

    print_db_command
  end

  def print_db_command
    database_yml = YAML.load_file(@redmine_new.name + "/htdocs/config/database.yml")
    new_db_database = database_yml["production"]["database"]
    new_db_username = database_yml["production"]["username"]
    new_db_host = database_yml["production"]["host"].gsub(/127\.0\.0\.1/, "localhost")
    puts "mysql -u root -p"
    puts "CREATE DATABASE #{new_db_database} CHARACTER SET utf8;"
    puts "GRANT ALL PRIVILEGES ON #{new_db_database}.* TO '#{new_db_username}'@'#{new_db_host}';"
    puts "quit"
  end

  def create_db_dev
    puts "Mysql2 password?"
    password_db = gets
    client = Mysql2::Client.new(host: "localhost", username: "root", password: password_db, database: "mysql")
  end

  def generate_secret_token
    Dir.chdir(@redmine_new.name + "/htdocs/") do
      system "bundle exec rake generate_secret_token"
    end
  end

  def migration
    Dir.chdir(@redmine_new.name + "/htdocs/") do
      system "bundle exec rake db:migrate RAILS_ENV=production"
    end
  end

  def update_scripts_serviceinstall_bat
    target_file = "/scripts/serviceinstall.bat"
    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0)

    target_file_1 = @redmine_new.name + target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          line = line.gsub(/\/#{@redmine_source.name}/, "/" + @redmine_new.name)
          line = line.gsub(/#{@redmine_source.name}Thin/, @redmine_new.name + "Thin")
          line = line.gsub(/#{@redmine_source.port1}/, @redmine_new.port1)
          line = line.gsub(/#{@redmine_source.port2}/, @redmine_new.port2)
          fw.puts line
        }
      }
    }

    puts "please install service"
    puts "#{File.expand_path(target_file_0)} INSTALL"
  end

  def update_scripts_servicerun_bat
    target_file = "/scripts/servicerun.bat"
    target_file_0 = @redmine_source.name + target_file
    exit if !check_file(target_file_0)

    target_file_1 = @redmine_new.name + target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          line = line.gsub(/#{@redmine_source.name}Thin/, @redmine_new.name + "Thin")
          fw.puts line
        }
      }
    }
  end

  def update_main_serviceinstall_bat
    target_file = "../serviceinstall.bat"

    target_file_0 = target_file + ".tmp"
    target_file_1 = target_file
    exit if !check_file(target_file_1, true)

    FileUtils.cp(target_file_1, target_file_0)  # create temp file

    line_buf = ""
    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          if line.match(/^rem redmine_code_end/)
            line_buf = line_buf.gsub(/\\#{@redmine_source.name}\\/, "\\#{@redmine_new.name}\\" )
            fw.puts line_buf
          else
            line_buf = line
          end
          fw.puts line
        }
      }
    }

    FileUtils.rm(target_file_0)  # remove temp file
  end

  def update_main_servicerun_bat
    target_file = "../servicerun.bat"

    target_file_0 = target_file + ".tmp"
    target_file_1 = target_file
    exit if !check_file(target_file_1, true)

    FileUtils.cp(target_file_1, target_file_0)  # create temp file

    line_buf = ""
    File.open(target_file_1, mode = "w"){|fw|
      File.open(target_file_0, mode = "rt"){|fr|
        fr.each_line{|line|
          if line.match(/^rem redmine_code_end/)
            line_buf = line_buf.gsub(/\\#{@redmine_source.name}\\/, "\\#{@redmine_new.name}\\" )
            fw.puts line_buf
          else
            line_buf = line
          end
          fw.puts line
        }
      }
    }

    FileUtils.rm(target_file_0)  # remove temp file
  end

  def update_main_properties_ini
    target_file = "../properties.ini"

    target_file_1 = target_file
    exit if !check_file(target_file_1, true)

    File.open(target_file_1, mode = "a"){|fw|
      fw.puts "[Thin_#{@redmine_new.name}-1]"
      fw.puts "thin_server_port=#{@redmine_new.port1}"
      fw.puts "thin_unique_service_name=#{@redmine_new.name}Thin1"
      fw.puts "[Thin_#{@redmine_new.name}-2]"
      fw.puts "thin_server_port=#{@redmine_new.port2}"
      fw.puts "thin_unique_service_name=#{@redmine_new.name}Thin2"
    }
  end
end



# ----- main script -----
ope_clone_redmine = CloneRedmine.new

puts "Update source Redmine settings for multiplexing?"
puts "(You only need to do this once.) y/[n]"
ret = gets.chomp
if ret.match(/^[yY]$/)
  ope_clone_redmine.update_additional_environment_rb_source
  ope_clone_redmine.update_configuration_yml_source
end

ope_clone_redmine.xcopy
ope_clone_redmine.clear_plugins
ope_clone_redmine.update_bitnami_apps_prefix_conf
ope_clone_redmine.update_conf_httpd_app_conf
ope_clone_redmine.update_conf_httpd_prefix_conf
ope_clone_redmine.update_conf_httpd_vhosts_conf
ope_clone_redmine.update_additional_environment_rb
ope_clone_redmine.update_config_database_yml
ope_clone_redmine.generate_secret_token
ope_clone_redmine.migration
ope_clone_redmine.update_scripts_serviceinstall_bat
ope_clone_redmine.update_scripts_servicerun_bat
ope_clone_redmine.update_main_serviceinstall_bat
ope_clone_redmine.update_main_servicerun_bat
ope_clone_redmine.update_main_properties_ini
