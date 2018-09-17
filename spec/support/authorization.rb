# Copyright (C) 2009-2018 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The default test collection.
#
# @since 2.0.0
TEST_COLL = 'test'.freeze

# An invalid write concern.
#
# @since 2.4.2
INVALID_WRITE_CONCERN = { w: 4 }

# Gets the root system administrator user.
#
# @since 2.0.0
ROOT_USER = Mongo::Auth::User.new(
  user: SpecConfig.instance.user || 'root-user',
  password: SpecConfig.instance.password || 'password',
  roles: [
    Mongo::Auth::Roles::USER_ADMIN_ANY_DATABASE,
    Mongo::Auth::Roles::DATABASE_ADMIN_ANY_DATABASE,
    Mongo::Auth::Roles::READ_WRITE_ANY_DATABASE,
    Mongo::Auth::Roles::HOST_MANAGER,
    Mongo::Auth::Roles::CLUSTER_ADMIN
  ]
)

# Get the default test user for the suite on versions 2.6 and higher.
#
# @since 2.0.0
TEST_USER = Mongo::Auth::User.new(
  database: SpecConfig.instance.test_db,
  user: 'test-user',
  password: 'password',
  roles: [
    { role: Mongo::Auth::Roles::READ_WRITE, db: SpecConfig.instance.test_db },
    { role: Mongo::Auth::Roles::DATABASE_ADMIN, db: SpecConfig.instance.test_db },
    { role: Mongo::Auth::Roles::READ_WRITE, db: 'invalid_database' },
    { role: Mongo::Auth::Roles::DATABASE_ADMIN, db: 'invalid_database' },
		{ role: Mongo::Auth::Roles::READ_WRITE, db: 'hr' },           # For transactions examples
		{ role: Mongo::Auth::Roles::DATABASE_ADMIN, db: 'hr' },       # For transactions examples
		{ role: Mongo::Auth::Roles::READ_WRITE, db: 'reporting' },    # For transactions examples
		{ role: Mongo::Auth::Roles::DATABASE_ADMIN, db: 'reporting' } # For transactions examples

  ]
)

# Provides an authorized mongo client on the default test database for the
# default test user.
#
# @since 2.0.0
AUTHORIZED_CLIENT = ClientRegistry.instance.new_global_client(
  SpecConfig.instance.addresses,
  SpecConfig.instance.test_options.merge(
    database: SpecConfig.instance.test_db,
    user: TEST_USER.name,
    password: TEST_USER.password)
)

# Provides an authorized mongo client that retries writes.
#
# @since 2.5.1
AUTHROIZED_CLIENT_WITH_RETRY_WRITES = AUTHORIZED_CLIENT.with(retry_writes: true)

# Provides an unauthorized mongo client on the default test database.
#
# @since 2.0.0
UNAUTHORIZED_CLIENT = ClientRegistry.instance.new_global_client(
  SpecConfig.instance.addresses,
  SpecConfig.instance.test_options.merge(database: SpecConfig.instance.test_db, monitoring: false)
)

# Provides an unauthorized mongo client on the admin database, for use in
# setting up the first admin root user.
#
# @since 2.0.0
ADMIN_UNAUTHORIZED_CLIENT = ClientRegistry.instance.new_global_client(
  SpecConfig.instance.addresses,
  SpecConfig.instance.test_options.merge(database: Mongo::Database::ADMIN, monitoring: false)
)

# Get an authorized client on the test database logged in as the admin
# root user.
#
# @since 2.0.0
ADMIN_AUTHORIZED_TEST_CLIENT = ADMIN_UNAUTHORIZED_CLIENT.with(
  user: ROOT_USER.name,
  password: ROOT_USER.password,
  database: SpecConfig.instance.test_db,
  auth_source: SpecConfig.instance.auth_source || Mongo::Database::ADMIN,
  monitoring: false
)

# A client that has an event subscriber for commands.
#
# @since 2.5.1
SUBSCRIBED_CLIENT = ClientRegistry.instance.new_global_client(
    SpecConfig.instance.addresses,
    SpecConfig.instance.test_options.merge(
      database: SpecConfig.instance.test_db,
      user: TEST_USER.name,
      password: TEST_USER.password)
)
SUBSCRIBED_CLIENT.subscribe(Mongo::Monitoring::COMMAND, EventSubscriber)
AUTHROIZED_CLIENT_WITH_RETRY_WRITES.subscribe(Mongo::Monitoring::COMMAND, EventSubscriber)

module Authorization

  # On inclusion provides helpers for use with testing with and without
  # authorization.
  #
  #
  # @since 2.0.0
  def self.included(context)

    # Gets the root system administrator user.
    #
    # @since 2.0.0
    context.let(:root_user) { ROOT_USER }

    # Get the default test user for the suite.
    #
    # @since 2.0.0
    context.let(:test_user) { TEST_USER }

    # Provides an authorized mongo client on the default test database for the
    # default test user.
    #
    # @since 2.0.0
    context.let(:authorized_client) { AUTHORIZED_CLIENT }

    # A client with a different cluster, for testing session use across
    # clients
    context.let(:another_authorized_client) do
      new_local_client(
        SpecConfig.instance.addresses,
        SpecConfig.instance.test_options.merge(
          database: SpecConfig.instance.test_db,
          user: TEST_USER.name,
          password: TEST_USER.password,
          heartbeat_frequency: 10,
        ),
      )
    end

    # Provides an authorized mongo client on the default test database that retries writes.
    #
    # @since 2.5.1
    context.let(:authorized_client_with_retry_writes) do
      EventSubscriber.clear_events!
      AUTHROIZED_CLIENT_WITH_RETRY_WRITES
    end

    # Provides an authorized mongo client that has a Command subscriber.
    #
    # @since 2.5.1
    context.let(:subscribed_client) do
      EventSubscriber.clear_events!
      SUBSCRIBED_CLIENT
    end

    # Provides an unauthorized mongo client on the default test database.
    #
    # @since 2.0.0
    context.let!(:unauthorized_client) { UNAUTHORIZED_CLIENT }

    # Provides an unauthorized mongo client on the admin database, for use in
    # setting up the first admin root user.
    #
    # @since 2.0.0
    context.let!(:admin_unauthorized_client) { ADMIN_UNAUTHORIZED_CLIENT }

    # Get an authorized client on the test database logged in as the admin
    # root user.
    #
    # @since 2.0.0
    context.let!(:root_authorized_client) { ADMIN_AUTHORIZED_TEST_CLIENT }

    # Gets the default test collection from the authorized client.
    #
    # @since 2.0.0
    context.let(:authorized_collection) do
      authorized_client[TEST_COLL]
    end

    # Gets the default test collection from the unauthorized client.
    #
    # @since 2.0.0
    context.let(:unauthorized_collection) do
      unauthorized_client[TEST_COLL]
    end

    # Gets a primary server for the default authorized client.
    #
    # @since 2.0.0
    context.let(:authorized_primary) do
      authorized_client.cluster.next_primary
    end

    # Get a primary server for the client authorized as the root system
    # administrator.
    #
    # @since 2.0.0
    context.let(:root_authorized_primary) do
      root_authorized_client.cluster.next_primary
    end

    # Get a primary server from the unauthorized client.
    #
    # @since 2.0.0
    context.let(:unauthorized_primary) do
      authorized_client.cluster.next_primary
    end

    # Get a default address (of the primary).
    #
    # @since 2.2.6
    context.let(:default_address) do
      authorized_client.cluster.next_primary.address
    end

    # Get a default app metadata.
    #
    # @since 2.4.0
    context.let(:app_metadata) do
      authorized_client.cluster.app_metadata
    end
  end
end
