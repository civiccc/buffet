require 'json'

# The principal (and only) export of CommitWatcher is the class watch() function
# that calls its block whenever a new commit is pushed to the provided branch 
# on the provided repository.
#
# Will always run the block immediately. 

class CommitWatcher
  # kwargs:
  #   Required:
  #     :username => A github username with permissions to access the repo.
  #     :token => The username's authentication token. 
  #     :repository => The repository we're interested in.
  #     :owner => Owner of the github repository.
  #
  #  Optional:
  #     :branch => Branch to run on. Defaults to master.
  def self.watch kwargs
      kwargs[:branch] = kwargs[:branch] || "master"

      old_commit_message = ""

      while true
        api_call = "curl -u '#{kwargs[:username]}/token:#{kwargs[:token]}' 'https://github.com/api/v2/json/commits/list/#{kwargs[:owner]}/#{kwargs[:repository]}/master'"

        commit_message = JSON.parse(`#{api_call}`)["commits"].first["message"]

        yield if commit_message != old_commit_message

        old_commit_message = commit_message
        sleep 2
      end
  end
end
