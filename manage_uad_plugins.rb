#!/usr/bin/env ruby

require 'tty-prompt'
require 'fileutils'
require 'shellwords'

######################## 1.1, 2020/24/5
#
# Feature complete!
#
# New:   Safely handle plugin upgrades by placing old versions into a backup folder
#        - backup folder with timestamp created only when upgrading plugins.
# Fixed: Duplicate names shown after undo
# Fixed: A few smaller bugs, and naming changes
#

input_file = "uad_plugins_i_own.list"

uad_plugins_installed   = "uad_plugins_installed.list"
uad_plugins_managed     = "uad_plugins_managed.list"

path_library_components  = "/Library/Audio/Plug-Ins/Components/"
path_library_vst         = "/Library/Audio/Plug-Ins/VST/Powered Plug-Ins/"
path_library_vst_mono    = "/Library/Audio/Plug-Ins/VST/Powered Plug-Ins/mono/"

path_managed = Dir.pwd + "/managed_plugins/"

path_managed_components  = path_managed + "components/"
path_managed_vst         = path_managed + "vst/"
path_managed_vst_mono    = path_managed + "vst/mono/"

time = Time.new
path_managed_backup = Dir.pwd + "/managed_plugins/backup_#{time.year}#{time.month}#{time.day}_#{time.hour}_#{time.min}/"

path_managed_backup_components  = path_managed_backup + "components/"
path_managed_backup_vst         = path_managed_backup + "vst/"
path_managed_backup_vst_mono    = path_managed_backup + "vst/mono/"

def create_upgrade_backup_folders( path_managed_backup, path_managed_backup_components, path_managed_backup_vst, path_managed_backup_vst_mono )
    print "\nCREATING BACKUP FOLDERS for upgraded plugins:  \n'#{path_managed_backup_components}'\n'#{path_managed_backup_vst}'\n'#{path_managed_backup_vst_mono}'\n\n"

    FileUtils.mkdir_p(path_managed_backup_components)
    FileUtils.mkdir_p(path_managed_backup_vst)
    FileUtils.mkdir_p(path_managed_backup_vst_mono)
end

#----------------------------------------------------------------------------- managed_plugin_upgrade
# Executed when there is a newer version of a plugin in the system folder.
# The old managed plugin will be deleted, and replaced with the new version.
#
def managed_plugin_upgrade(path_from, path_to, path_backup, name_plugin, extension)
    #
    from = "#{path_from}#{name_plugin}"
    to = "#{path_to}#{name_plugin}"
    backup = "#{path_backup}#{name_plugin}"
    # 
    if !File.exist?("#{from}.#{extension}")
        # print "\n        SKIPPING UPGRADE:  '#{from}.#{extension}', REASON: Upgraded plugin not found in System plugins"
        return false
    end
    if !File.exist?("#{to}.#{extension}")
        # print "\n        SKIPPING UPGRADE:  '#{from}.#{extension}', REASON: Old plugin not found in managed folder"
        return false
    end
    #
    if File.mtime("#{from}.#{extension}") > File.mtime("#{to}.#{extension}")
        print "\n\n>>>-------- UPGRADING: '#{name_plugin}' (component, vst, and vst mono)\n"
        # move old plugin to backup
        File.rename "#{to}.#{extension}", "#{backup}.#{extension}"
        # move upgraded plugin to managed
        File.rename "#{from}.#{extension}", "#{to}.#{extension}"
        return true
    end
end

#----------------------------------------------------------------------------- managed_plugin_check_for_upgrade
# Executed to see if there is a newer version of a plugin in the system folder.
#
def managed_plugin_check_for_upgrade(path_from, path_to, name_plugin, extension)
    #
    from = "#{path_from}#{name_plugin}"
    to = "#{path_to}#{name_plugin}"
    # 
    if !File.exist?("#{from}.#{extension}")
        # print "\n        SKIPPING UPGRADE:  '#{from}.#{extension}', REASON: Upgraded plugin not found in System plugins"
        return 0
    end
    if !File.exist?("#{to}.#{extension}")
        # print "\n        SKIPPING UPGRADE:  '#{from}.#{extension}', REASON: Old plugin not found in managed folder"
        return 0
    end
    #
    if File.mtime("#{from}.#{extension}") > File.mtime("#{to}.#{extension}")
        return 1
    end
    return 0
end
#----------------------------------------------------------------------------- manage_plugin
#
#
def manage_plugin(path_from, path_to, name_plugin, extension)
    #
    from = "#{path_from}#{name_plugin}"
    to = "#{path_to}#{name_plugin}"
    # 
    if !File.exist?("#{from}.#{extension}")
        # print "\n        SKIPPING:  '#{from}.#{extension}', REASON: Plugin not found in System plugins"
        return false
    elsif File.exist?("#{to}.#{extension}")
        # print "\n        SKIPPING:  '#{from}.#{extension}', REASON: Plugin found in managed folder"
        return false
    end
    #
    #print "\n\n>>>-------- MOVING OUT: '#{name_plugin}' (component, vst, and vst mono)" 
    File.rename "#{from}.#{extension}", "#{to}.#{extension}"
    return true
end

#----------------------------------------------------------------------------- manage_plugin_purchased
#
#
def manage_plugin_purchased(path_from, path_to, name_plugin, extension)
    #
    from = "#{path_from}#{name_plugin}"
    to = "#{path_to}#{name_plugin}"
    # 
    if !File.exist?("#{from}.#{extension}")
        # print "\n        SKIPPING:  '#{from}.#{extension}', REASON: Plugin not found in managed"
        return false
    elsif File.exist?("#{to}.#{extension}")
        # print "\n        SKIPPING:  '#{from}.#{extension}', REASON: Already in System plugins"
        return false
    end
    #
    # print "\n\n>>>-------- MOVING IN: '#{name_plugin}' (component, vst, and vst mono)" 
    File.rename "#{from}.#{extension}", "#{to}.#{extension}"
    return true
end

#----------------------------------------------------------------------------- manage_plugins_commit_changes
#
# Move plugins between managed folders, and the system plugin folders for components and VSTs
#
def manage_plugins_commit_changes(input_file,path_library_components,path_library_vst,path_library_vst_mono,path_managed_components,path_managed_vst,path_managed_vst_mono)
    line_num = 0

    text=File.open(input_file).read

    text.gsub!(/\r\n?/, "\n") # clean up file names

    text.each_line do |line|

        line = line.chomp

        next if(line.start_with?("#")) # skip comments in files

        if(!line.start_with?(">")) # NOT a plugin that I own?

            if(manage_plugin(path_library_components, path_managed_components, line, "component")===true)
                manage_plugin(path_library_vst, path_managed_vst, line, "vst")
                manage_plugin(path_library_vst_mono, path_managed_vst_mono, "#{line}(m)", "vst")

                print "\n#{line_num += 1}: >>>-------- MOVED TO MANAGED: '#{line}' (component, vst, and vst mono)\n" 
            end

        else # it is a plugin that we own. We'll check if it needs to be moved to system plugins folder
            line[0] = ''
           
            if(manage_plugin_purchased(path_managed_components, path_library_components, line, "component")===true)
                manage_plugin_purchased(path_managed_vst, path_library_vst, line, "vst")
                manage_plugin_purchased(path_managed_vst_mono, path_library_vst_mono, "#{line}(m)", "vst")

                print "\n#{line_num += 1}: <<<-------- MOVED TO SYSTEM: '#{line}' (component, vst, and vst mono)\n" 
            end

        end
    end
    print "\n\n----- DONE -----\n\n"
end

def generate_uad_plugin_lists(path_library_components, path_managed_components, uad_plugins_installed, uad_plugins_managed)

    list_installed =  "ls #{path_library_components}UAD* | grep 'UAD*' | sed \"s/.*\\///\" | sed 's/\.[^.]*$//' > #{uad_plugins_installed}"
    list_managed   =  "ls #{path_managed_components}UAD* | grep 'UAD*' | sed \"s/.*\\///\" | sed 's/\.[^.]*$//' > #{uad_plugins_managed}"
    
    system(list_installed)
    system(list_managed)
end


#==========================================================================================================================================
#
#   Main app
#
UADPlugin = Struct.new(:name, :own)
uad_plugins = []

#
# Is this the first time we're running the manager?
#
if(File.file?(uad_plugins_installed) && File.file?(uad_plugins_managed))
    #
    # no! check if there are upgraded versions of managed plugins in the system folder
    #
    print("\nScanning for upgraded plugins...\n")

    text=File.open(uad_plugins_managed).read

    text.each_line do |plugin|
        uad_plugins << UADPlugin.new(plugin.chomp,0)
    end

    count_upgrades = 0
    
    uad_plugins.each { |p|
        #print("\nPlugin: #{p.name}\n")
        count_upgrades += managed_plugin_check_for_upgrade(path_library_components, path_managed_components, p.name, "component")
    }

    if( count_upgrades > 0 )

        print "\n\n   Found [ #{count_upgrades} ] upgraded plugins. Moving old plugins to: #{path_managed_backup} (you can delete that folder if all looks fine)\n\n"

        create_upgrade_backup_folders path_managed_backup, path_managed_backup_components, path_managed_backup_vst, path_managed_backup_vst_mono

        uad_plugins.each { |p|
            print("\nPlugin: #{p.name}\n")
            managed_plugin_upgrade(path_library_components, path_managed_components, path_managed_backup_components, p.name, "component")
            managed_plugin_upgrade(path_library_vst, path_managed_vst, path_managed_backup_vst, p.name, "vst")
            managed_plugin_upgrade(path_library_vst_mono, path_managed_vst_mono, path_managed_backup_vst_mono, "#{p.name}(m)", "vst")
        }

    end
end

generate_uad_plugin_lists(path_library_components, path_managed_components, uad_plugins_installed, uad_plugins_managed)

i_count_owned = 0

text=File.open(uad_plugins_installed).read

uad_plugins.clear()

text.each_line do |plugin|
    i_count_owned += 1
    uad_plugins << UADPlugin.new(plugin.chomp,1)
end

text=File.open(uad_plugins_managed).read

text.each_line do |plugin|
    uad_plugins << UADPlugin.new(plugin.chomp,0)
end

uad_plugins.sort! { |pA, pB| pA.name.downcase <=> pB.name.downcase }

prompt = TTY::Prompt.new(interrupt: :exit)

choice = prompt.select("\n-------------------------------------------------------------------- UAD Plugin Manager\n") do |menu|
    menu.choice 'Manage my UAD plugins', 1, help: "Something"
    
    if(i_count_owned === 0)
        menu.choice 'Undo everything', 2, disabled: '(no managed plugins found)'
    else
        menu.choice 'Undo everything', 2
    end
    menu.choice 'Exit', -> { exit 0 }
end

if(choice === 1)
    i_own = prompt.multi_select("\n------------------------------------------------------------------ UAD Plugins I own: (count: #{i_count_owned})\n(press SPACEBAR to toggle select | ENTER to proceed)\n\n", per_page: 20, active_color: :green, help_color: :white) do |menu|
        selected = []
        i = 0
        uad_plugins.each { |p|
            menu.choice p.name, p.name
            i += 1
            if(p.own > 0)
                selected.push(i)
            end
        }
        menu.default.concat(selected)
    end

    #
    # Update changes to plugins I own
    #
    i = 0
    uad_plugins.each { |p|
        p.own = (i_own.index(p.name) === nil) ? 0 : 1
        # print "#{p.name} < #{p.own}\n"
    }
    open(input_file, 'w') do |f|
        uad_plugins.each { |p|
            if(p.own === 1)
                f.puts ">#{p.name}"
            elsif
                f.puts "#{p.name}"
            end
        }
    end    
    manage_plugins_commit_changes(input_file,path_library_components,path_library_vst,path_library_vst_mono,path_managed_components,path_managed_vst,path_managed_vst_mono)

elsif(choice === 2) # put all the UAD plugins back as they were?
    yes = prompt.select('You want to restore all UAD plugins back to their original location?') do |menu|
        menu.choice 'No', false
        menu.choice 'Yes', true
    end
    if(yes)
        open(input_file, 'w') do |f|
            uad_plugins.each { |p|
                f.puts ">#{p.name}" # mark all as owned, in order to restore everything
            }
        end
        manage_plugins_commit_changes(input_file,path_library_components,path_library_vst,path_library_vst_mono,path_managed_components,path_managed_vst,path_managed_vst_mono)
    end
end