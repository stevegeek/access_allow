# AccessAllow

Permissions and access control gem for Rails.

# Roles, Abilities and the permissions model

Users should be assigned a `role` where a role is a named grouping of specific permissions (or abilities as we
call them). Roles are configured in the application configuration.

Abilities are named permissions that live inside a namespace. These are context dependant. For example we might think
of the ability for being able to check out a shopping cart as `shopping_cart: :check_out` where `shopping_cart` is the
ability namespace for anything to do with the shopping cart and `check_out` is the specific ability name.

Thus abilities are acquired by user either through their assigned role, or an ability can be directly assign in the
database, via the User association `permissions`.

## Role and abilities utility methods

`AccessAllow::Roles` provides a bunch of utility methods that

* check if a given role name is for a specific user type or not
* returns humanized versions of the role names

`AccessAllow::Abilities` currently provides utility methods to convert between string and hash representations of abilities.

# Configuring Roles & their abilities

Schema configured in `Configuration` and should be configured to create roles with their abilities.

The structure consists of:

    <user_type_key>:
      <user_role_key>:
        <ability_namespace_key>:
          <ability_key>: [true/false]

where

* `user_type_key` is determined from the model name of the user class (eg `User` => `user`)
* `user_role_key` is the name of the user role (eg `account_owner`)
* `ability_namespace_key` is the name of the group of abilites (eg `product_management`)
* `ability_key` is the name of the actual ability (eg `edit_product`) and is set to a boolean
  to indicate if the ability is available to the specific configuration or not

__Note__: ability names must be defined in the correct user type, role, namespace key space otherwise
the app will raise an exception. This is to prevent accidentally forgetting to define the default
permissions of a role around a specific feature.

## Setting a user specific ability

User specific abilities are persisted in `Permission`s where the attribute `ability_name` stores the
ability namespace and name in one combined string. The format is `/` separated. Eg `tag_management/edit_tag`. Use
`AccessAllow::Abilities` to convert between string and hash representations of abilities.

The existence of a `Permission` sets the specific ability in the above described structure of abilities.

The `AbilitiesManager` handles mixing these assigned abilities into the users specific total ability list.

__Note__ that an ability defined in a `Permission` __must__ also exist in the role assigned abilities. If
it does not then it is ignored. In other words a `Permission` can only override abilities defined for the
role that are set to `false`. This allows a user to be given a specific ability that normally their role has not got,
but does not allow you to assign arbitrary abilities to a user, thus preventing dangerous situations where an ability
that say is only for Admins is assigned to a User role.

# Manually checking user abilities

The class `AccessAllow::Check` implements ability check logic. Using this class one can check if a user has a specific ability
and optionally raise if not.

You can either build a new instance of the check class and then use `#possible?` and `#possible!` of use the class
helper methods

* `.call(user, <ability_namespace>: <ability_name>)`: checks if user has `ability_name` in `ability_namespace`. Returns
  a boolean result
* `.call!(user, <ability_namespace>: <ability_name>)`: checks if user has `ability_name` in `ability_namespace`. Returns
  true or raises `AccessAllow::ViolationError`

The methods exposed by `Check` are useful for checking for abilities in other objects. To define abilities checks
around controller actions see the next section.

# Controller DSL for specifying requirements and abilities needed to perform actions

Much of the time permissions checks will occur in Controllers. Also many controller actions have specific checks and
requirements around the user or other entities related to the controller action. For example, when editing a user's
profile, one must check that the user who is trying to execute the `update` action has the ability (permission) to
do it, but also that the user is even from the same company as the user being edited.

As such a DSL exists that can be used in controllers to define sets of required checks and rules around actions that then 
define what abilities or checks are needed to allow a specific action to execute. The rules can also define what
should happen if the checks do not pass, or if no rules match the current situation.

The DSL allows us to define 3 categories of our so called access rules:

## Required check rules

Many times we want to specify that certain requirements are required to allow a user to perform a certain action. These
requirements maybe certain checks on the user, or they maybe related to their role or abilities.

These checks must all pass to allow the user to continue. They are checked before any other access checks are executed.
If the checks do not pass then a 'violation' is returned, which is then handled by the controller accordingly.

These rules consist of a 'check', an optional set of required abilities, and optionally what violation type to raised
if the check does not pass.

## Action allow rules

Action allow rules are defined to provide specific rules which allow a user to perform a specific controller action. 

Note that AccessAllow prevents an action from being executed unless it is explicitly allowed for the given user trying to
execute it.

For a user to be allowed to perform a given controller action, there must be a matching "action allow" rule for that
action for which the check passes and permissions requirements are met. Any matching rule will allow the user to execute
the action. Note if no rules match successfully then the no-match behaviour is executed.

These rules consist of a check, an optional set of required abilities, a set of action names to which the rule applies
and optionally a name to alias the check as a "named check" rule (see below).

## Named check rule

These are named checks that can then be referenced by name in action logic or in views to say perform some conditional
logic. The method provided for checking if any named check rule is valid for the current context is `access_allowed?`.
There is more details below on this.

Say for example you want a user to be `approved` and have the ability `company_profile/edit` to edit the company
profile, and want to conditionally display a "Edit" button in the view. You could define a named check, say
`:approved_can_edit` (that checks `approved` and that the user has the ability) and use it in the view to conditionally 
display the button:

    <% if access_allowed? :approved_can_edit %>
      The button...
    <% end %>

Note that when you define an "action allow" rule it is automatically also added to these 'named checks' by the action
name, for example, if there is action allow rule for `:create` then we can use `access_allowed? :create`. 

Also note that it is possible to specify a custom 'named check' name for the "action allow" rule (see more below).

## No-match behaviour

The DSL also allows us to define what should happen when executing an action and no rule matches the current situation.

What should happen is defined using one of a set of predefined 'violations' which are handled in specific ways. See
the discussion below on violations.

## Violations

The behaviour when a "required check" or an action has no matching "allow rule" is defined with so called "violation"
configuration. These violations are handled in a standardised way by the controller callback that performs the rule
checks.

The violation types are:

* `severe`:
  this violation is considered something unusual and is logged. The end user will simply see a 404 page to avoid exposing 
  to them that there is in fact an actionable endpoint at the route they tried to access.
* `hidden`:
  this violation type is considered less severe, but still aims to avoid leaking information to the end user
  about the actual available routes on the app. If this violation is raised the user will see a 404 page and
  the violation is logged to the app logs.
* `not_permitted`:
  this violation is used when a user can know that an action and route exists but that they do not
  have the assigned 'abilities' to perform the action. The end user will see a 403 (forbidden) page
  and the violation is simply logged to the app logs.
* `redirect`:
  this violation type is used when we want to perform a redirect if the user does not have the necessary
  permissions. By default it will redirect to `root_path` but you can use a block to specify the destination path.
  The block must return a string or other structure that is accepted by `redirect_to`.

## The DSL & defining checks

The methods are as follows:

### `access_require(check, with:, violation: :severe, &block)`

Used to define a "required check rule".

Takes a check name (a symbol or array of symbols) (see details below), an optional `violation` type (defaults to
`severe`) for when the check does not pass, and a block for when the violation type is `redirect` and you want to
specify custom logic to determine the redirection destination. Also can take an an optional set of abilities (a hash)
passed to `with:` to check against the user.

### `access_allow(check, with: nil, to:, as: nil)`

Used to define an "action allow rule" with optional named check alias.

Takes a check name (a symbol or array of symbols) (see details below), an optional set of abilities (a hash) passed to
`with:` to check against the user, and an optional name (symbol) passed with `as:` to allow the rule to be used as a
"named check". The controller actions the rule applies to is passed to `to:` (symbol or array of symbols).

### `access_allow(check, with: nil, as:)`

Used to define a "named check rule".

Similar to the "action allow rule" but without the actions. This rule is thus only available to be used as a "named
check".

### `access_no_match(violation, &block)`

Used to define the "no match" behaviour, ie what happens when an action is trying to be executed by no access rule
matches or passes for the given user and action.

Takes a `violation` type and optionally a block for when the violation type is `redirect` and you want to specify
custom logic to determine the redirection destination.

### Defining abilities needed

Permissions requirements are specified for the rule with `with:`.

The permissions are defined as a hash containing keys representing the ability namespaces and associated values
representing the required abilities.

For example, `{tag_management: [:add_new, :edit_existing], product_management: :edit_variants}` would mean that the
user must have all 3 of the abilities, `tag_management: :add_new`, `tag_management: :edit_existing` and
`product_management: :edit_variants`.

### Defining Checks & predefined checks

Access rules must specify one or more 'checks' as part of their rule definition.

'Checks' are basically controller methods which return a boolean to determine if the check 'passed' or 'failed'. Checks
are normally custom code written for the given context of the feature. Note that checks do not need to perform the
abilities checks specified by `with:`, these are performed by the gem logic for you.

Checks are specified by providing an instance method on the controller named `allow_(name)?`, where `name` is the check
name, and which returns a boolean.

For example, if defining a check for an action allow rule where the user must be approved on the platform, and
have a specific ability assigned to them, then the 'check' part (named say `approved_user`) is "user must be approved
on the platform" part of the rule, and would be defined on the controller as an instance method `allow_approved_user?`.

There are some predefined 'common' checks, where you do not need to define the `allow_(name)?` method. These are:

* `:public`: anyone, logged in or not
* `:authenticated_user`: any logged in user  (uses `current_user` or whatever is set as the `current_user_method` in the config)

# View helper to check permissions of user for conditional view sections

It is also possible to check `access` rules from inside views using the `access_allowed?` view helper, which takes
a list of "named check" names. If any of those check names passes the method returns `true`.

Note that check names also include the actions for which rules exists, as described earlier.

```erb
    # in controller
    allow_access :admin, to: :new

    # in view
    <% if access_allowed? :new %>
      Only 'admin' users who are allowed to execute action `:new` can see this
    <% end %>
```

and

```erb
    # in controller
    allow_access :my_check, as: named_rule

    # in view
    <% if access_allowed? :named_rule %>
      Only users for whom the `named_rule` check passes can see this
    <% end %>
```

# Example

Consider the following view fragment, and then the controller heirarchy defined below:

`tags_controller.rb`

```ruby
class TagsController < AdminController
  # Allow any admin to access the :index and :show actions
  access_allow :admin, to: [:index, :show]
  # Only let admins with the ability `tag_management: :manage` to execute other actions.
  # Also in our view we can use the check name `tag_management` to conditionally add say an "Add new Tag" button
  access_allow :admin, with: {tag_management: :manage}, to: :all, as: :tag_management
  # On the index page we also conditionally show some statistics about Tag usage, but only to admins with the right
  # ability. This is done with the named check `:view_usage_stats`
  access_allow :admin, with: {tag_management: :usage_stats}, as: :view_usage_stats
  # Admins with a special flag called "im_magic" can also access the :magic action
  access_allow :magic_admin, to: :magic
  
  def allow_admin?
    current_user.admin?
  end
  
  def allow_magic_admin?
    current_user.im_magic? && allow_admin?
  end
  
  # ...
end

class AdminController < AuthenticatedController
  # Only admins can access actions on this controller or its sub controllers. Any authenticated user who is not an
  # admin user will generate a severe access violation. They will see a 404 but the violation will be logged.
  access_require :admin, violation: :severe
  # Once we have verified the user is an admin we can 403 them instead of 404 when they try to access a page they
  # dont have permission for. We don't need to hide the existence of the action from them.
  access_no_match :not_permitted
  # ...
end

class AuthenticatedController < ApplicationController
  # Any action requires an authenticated user. The defined behaviour is that if the user trying to access the action
  # is not authenticated they are redirected to the sign-in page.
  access_require :authenticated_user, violation: :redirect do
    sign_in_path
  end

  # ...
end

class ApplicationController < ActionController::Base
  # By default, if no access rules match when executing an action then show the user a 404 to prevent leaking the
  # existence of the end point
  access_no_match :hidden
  # ...
end

```

`tags/index.html.erb`

```erb
    <p>Tags Index</p>
    <% if access_allowed? :tag_management %>
      <button>Add new tag</button>
    <% end %>
    <% if access_allowed? :view_usage_stats %>
      <div> ... </div>
    <% end %>
    <ul> ... </ul>
```

## Usage

Add this to your `ApplicationController`

```ruby
class ApplicationController < ActionController::Base
  include AccessAllow::ControllerAccessDsl
end
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem "access_allow"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install access_allow
```

Then run the **generator to add the initializer**

    rails g access_allow:install


## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
