class SyncNetworkGroups < SimpleService
  def initialize(user)
    @user = user
    @roles = find_users_roles
  end

  def call
    begin
      return if @roles.size == 0
      assign_user_to_groups
    rescue JsonApiClient::Errors::ServerError
      return false
    end
  end

  private

  def find_users_roles
    NetworkApi::UsersRole.where(
      user_uid: @user.uid,
      role_resource_type: 'Group'
    ).includes(:role)
  end

  def assign_user_to_groups
    @roles.each do |users_role|
      role_name = users_role.role.name
      group_id = users_role.role.resource_id
      group = Group.find(group_id)
      debugger
      if !@user.has_role?(role_name, group)
        Roles::MassAssign.call(
          object: group,
          role_name: role_name,
          users: [@user],
        )
      end
    end
  end
end
