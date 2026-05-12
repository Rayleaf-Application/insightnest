defmodule Insightnest.Repo.Migrations.DropContributionsOnePerMemberPerSpark do
  use Ecto.Migration

  def change do
    drop_if_exists index(:contributions, [:spark_id, :author_id],
                     name: :contributions_one_per_member_per_spark)
  end
end
