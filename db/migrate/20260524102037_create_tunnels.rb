class CreateTunnels < ActiveRecord::Migration[8.1]
  def change
    create_table :tunnels do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :subdomain
      t.integer :local_port
      t.string :status
      t.string :token

      t.timestamps
    end
  end
end
