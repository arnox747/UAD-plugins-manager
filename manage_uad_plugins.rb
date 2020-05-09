#!/usr/bin/env ruby

require 'tty-prompt'
require 'fileutils'
require 'shellwords'

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

#
#   Main app
#
list_installed =  "ls #{path_library_components}UAD* | grep 'UAD*' | sed \"s/.*\\///\" | sed 's/\.[^.]*$//' > #{uad_plugins_installed}"
list_managed   =  "ls #{path_managed_components}* | grep 'UAD*' | sed \"s/.*\\///\" | sed 's/\.[^.]*$//' > #{uad_plugins_managed}"

system(list_installed)
system(list_managed)

UADPlugin = Struct.new(:name, :own)
uad_plugins = []

i_count_owned = 0

text=File.open(uad_plugins_installed).read

text.each_line do |plugin|
    i_count_owned += 1
    uad_plugins << UADPlugin.new(plugin.chomp,1)
end

text=File.open(uad_plugins_managed).read

text.each_line do |plugin|
    uad_plugins << UADPlugin.new(plugin.chomp,0)
end

uad_plugins.sort! { |pA, pB| pA.name.downcase <=> pB.name.downcase }

uad_plugins.each { |p|
    print "#{ (p.own > 0) ? ">" : "" }#{p.name}\n"
}

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

elsif(choice === 2) # decided to put all the UAD plugins back as they were?
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