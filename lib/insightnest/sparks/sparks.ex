defmodule Insightnest.Sparks do
  import Ecto.Query

  alias Insightnest.Repo
  alias Insightnest.Sparks.Spark

  # ── Queries ──────────────────────────────────────────────────────────────────

  @doc "Returns all published sparks, newest first."
  def list_published do
    Spark
    |> where([s], s.status == "published")
    |> order_by([s], desc: s.inserted_at)
    |> preload(:author)
    |> Repo.all()
    |> Enum.map(&compute_is_closed/1)
  end

  @doc "Returns a spark by ID with author preloaded. Raises if not found."
  def get_spark!(id) do
    Spark
    |> preload(:author)
    |> Repo.get!(id)
    |> compute_is_closed()
  end

  @doc "Returns a spark by slug with author preloaded. Raises if not found."
  def get_spark_by_slug!(slug) do
    Spark
    |> preload(:author)
    |> Repo.get_by!(slug: slug)
    |> compute_is_closed()
  end

  @doc "Returns the member's own sparks (draft + published), newest first."
  def list_by_author(author_id) do
    Spark
    |> where([s], s.author_id == ^author_id)
    |> order_by([s], desc: s.inserted_at)
    |> preload(:author)
    |> Repo.all()
    |> Enum.map(&compute_is_closed/1)
  end

  @doc "Full-text search over published sparks."
  def search_published(query) when byte_size(query) > 0 do
    Spark
    |> where([s], s.status == "published")
    |> where([s], fragment("search_vector @@ plainto_tsquery('english', ?)", ^query))
    |> order_by([s], desc: s.inserted_at)
    |> preload(:author)
    |> Repo.all()
    |> Enum.map(&compute_is_closed/1)
  end

  def search_published(_), do: list_published()

  # ── Commands ─────────────────────────────────────────────────────────────────

  def changeset(spark, attrs) do
    spark
    |> Ecto.Changeset.cast(attrs, [:title, :body, :status, :concepts])
    |> Ecto.Changeset.validate_required([:title, :body])

    # Add other validations as needed
  end

  @doc """
  Creates a spark for the given author.

  Enforces: if the author has any existing published sparks,
  at least one of them must have received a contribution before
  they can create another. First spark is always allowed.
  """
  def create_spark(attrs, author_id) do
    with :ok <- check_previous_spark_engaged(author_id) do
      timeout_days = Map.get(attrs, "timeout_days", 0) |> parse_int()
      closes_at    = compute_closes_at(timeout_days)
      content_hash = compute_content_hash(attrs, author_id)
      slug         = generate_slug(Map.get(attrs, "title", ""))

      %Spark{}
      |> Spark.changeset(
        attrs
        |> Map.put("author_id", author_id)
        |> Map.put("content_hash", content_hash)
        |> Map.put("slug", slug)
        |> Map.put("closes_at", closes_at)
      )
      |> Repo.insert()
    end
  end

  defp check_previous_spark_engaged(author_id) do
    # Count published sparks by this author
    published_count =
      Repo.aggregate(
        from(s in Spark,
          where: s.author_id == ^author_id and s.status == "published"
        ),
        :count
      )

    # First spark — always allowed
    if published_count == 0 do
      :ok
    else
      # Check if any published spark has at least one contribution
      has_engagement =
        Repo.exists?(
          from s in Spark,
            join: c in Insightnest.Contributions.Contribution,
              on: c.spark_id == s.id and c.status == "active",
            where: s.author_id == ^author_id and s.status == "published"
        )

      if has_engagement do
        :ok
      else
        # Find the most recent published spark for the error message
        last_spark =
          Repo.one(
            from s in Spark,
              where: s.author_id == ^author_id and s.status == "published",
              order_by: [desc: s.inserted_at],
              limit: 1
          )

        {:error, {:no_engagement, last_spark}}
      end
    end
  end

  @doc "Publishes a draft spark. Only the author can publish."
  def publish_spark(%Spark{} = spark, author_id) do
    if spark.author_id == author_id do
      spark
      |> Spark.publish_changeset()
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc "Updates a spark's title, body, or concepts. Only the author can update."
  def update_spark(%Spark{} = spark, attrs, author_id) do
    if spark.author_id == author_id do
      spark
      |> Spark.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc "Returns true if the given member is the spark's author."
  def author?(%Spark{author_id: aid}, member_id), do: aid == member_id

  def author?(spark_id, member_id) when is_binary(spark_id) do
    Repo.exists?(from s in Spark, where: s.id == ^spark_id and s.author_id == ^member_id)
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp compute_is_closed(%Spark{closes_at: nil} = spark), do: %{spark | is_closed: false}

  defp compute_is_closed(%Spark{closes_at: closes_at} = spark) do
    %{spark | is_closed: DateTime.compare(DateTime.utc_now(), closes_at) == :gt}
  end

  defp compute_closes_at(days) when is_integer(days) and days > 0 do
    DateTime.utc_now()
    |> DateTime.add(days * 86_400, :second)
    |> DateTime.truncate(:second)
  end

  defp compute_closes_at(_), do: nil

  defp compute_content_hash(attrs, author_id) do
    content =
      [
        Map.get(attrs, "title", ""),
        Map.get(attrs, "body", ""),
        author_id,
        DateTime.utc_now() |> DateTime.to_unix() |> to_string()
      ]
      |> Enum.join("|")

    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end

  defp generate_slug(title) do
    base = Slug.slugify(title) || "spark"
    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    "#{base}-#{suffix}"
  end

  defp parse_int(v) when is_integer(v), do: v

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_int(_), do: 0

  @max_extensions Application.compile_env(:insightnest, :spark_max_extensions, 2)
  @default_timeout Application.compile_env(:insightnest, :spark_default_timeout_days, 14)
  @max_timeout Application.compile_env(:insightnest, :spark_max_timeout_days, 90)

  @doc """
  Extends the closing time of a spark. Only the author can extend.
  Max extensions: 2. Extends from current deadline or now, whichever is later.
  """
  def extend_spark(%Spark{} = spark, author_id, additional_days \\ nil) do
    cond do
      spark.author_id != author_id ->
        {:error, :unauthorized}

      spark.extension_count >= @max_extensions ->
        {:error, :max_extensions_reached}

      true ->
        days = additional_days || @default_timeout
        days = min(days, @max_timeout)

        base = case spark.closes_at do
          nil -> DateTime.utc_now()
          closes_at ->
            if DateTime.compare(closes_at, DateTime.utc_now()) == :gt do
              closes_at
            else
              DateTime.utc_now()
            end
        end

        new_closes_at =
          base
          |> DateTime.add(days * 86_400, :second)
          |> DateTime.truncate(:second)

        spark
        |> Ecto.Changeset.change(
          closes_at: new_closes_at,
          extension_count: spark.extension_count + 1
        )
        |> Repo.update()
    end
  end
end
