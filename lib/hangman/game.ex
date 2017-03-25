require IEx
defmodule Hangman.Game do

  @moduledoc """

  This is the backend for a Hangman game. It manages the game state.
  Clients make moves, and this code validates them and reports back
  the updated state.

  Our API is

  * `game = Hangman.Game.new_game`
  * `{game, status, guess} = make_move(game, guess)`

  and the auxiliary functions

  * `status = get_status(game)`
  * `{game, status} = reset_game(game)`


## Example of use

Here's this module being exercised from an iex session. For all but
the first line we only show the resulting status (not the value of the
`game` variable).

    iex> alias Hangman.Game
    Hangman.Game
    #
    iex> { game, _initial_state } = Game.new_game("wombat"); game
    %{game_state: :in_progress, guess_state: nil, guessed: #MapSet<[]>,
      last_guess: nil, turns_left: 10,
      word: [{"w", false}, {"o", false}, {"m", false}, {"b", false}, {"a", false},
       {"t", false}]}
    #
    iex> { game, status } = Game.make_move(game, "a"); status
    %{game_state: :in_progress, guess_state: :good_guess, last_guess: "a",
      letters: ["_", "_", "_", "_", "a", "_"], turns_left: 10}
    #
    iex> { game, status } = Game.make_move(game, "b"); status
    %{game_state: :in_progress, guess_state: :good_guess, last_guess: "b",
      letters: ["_", "_", "_", "b", "a", "_"], turns_left: 10}
    #
    iex> { game, status } = Game.make_move(game, "c"); status
    %{game_state: :in_progress, guess_state: :bad_guess, last_guess: "c",
      letters: ["_", "_", "_", "b", "a", "_"], turns_left: 9}
    #
    iex> { game, status } = Game.make_move(game, "d"); status
    %{game_state: :in_progress, guess_state: :bad_guess, last_guess: "d",
      letters: ["_", "_", "_", "b", "a", "_"], turns_left: 8}
    #
    iex> { game, status } = Game.make_move(game, "a"); status
    %{game_state: :in_progress, guess_state: :already_guessed, last_guess: "a",
      letters: ["_", "_", "_", "b", "a", "_"], turns_left: 8}
    #
    iex> { game, status } = Game.make_move(game, "w"); status
    %{game_state: :in_progress, guess_state: :good_guess, last_guess: "w",
      letters: ["w", "_", "_", "b", "a", "_"], turns_left: 8}
    #
    iex> { game, status } = Game.make_move(game, "o"); status
    %{game_state: :in_progress, guess_state: :good_guess, last_guess: "o",
      letters: ["w", "o", "_", "b", "a", "_"], turns_left: 8}
    #
    iex> { game, status } = Game.make_move(game, "m"); status
    %{game_state: :in_progress, guess_state: :good_guess, last_guess: "m",
      letters: ["w", "o", "m", "b", "a", "_"], turns_left: 8}
    #
    iex> { _game, _status } = Game.make_move(game, "t"); status
    %{game_state: :won, guess_state: :good_guess, last_guess: "t",
      letters: ["w", "o", "m", "b", "a", "t"], turns_left: 8}
  """


  @type game   :: map
  @type status :: map
  @type ch     :: String.t
  @type optional_ch :: ch | nil

  @doc """
    Set up the state for a new game, and return that state. The client
    applications will pass this state back to your code in all the
    subsequent API calls.

        `game = Hangman.Game.new_game()`

    The `game` that's returned is an opaque structure used internally
    by this module. You'll likely want to use a map.

    As an aid to testing, there's a second form of this function:

        `{ game, status } = Hangman.Game.new_game(word)`

    This forces `word` to be this game's hidden word.
  """

  @spec new_game(String.t) :: game

  def new_game(word \\ Hangman.Dictionary.random_word) do
    %{
      last_guess: nil,
      game_state: :in_progress,
      guess_state: nil,
      turns_left: 10,
      guessed: [],
      letters: starting_letters(word),
      word: word_as_list_of_tuples(word)
    }
  end

  def word_as_list_of_tuples(word) do
    String.codepoints(word)
    |> Enum.map(&({&1, false}))
  end

  def starting_letters(word) do
    Enum.map(1..String.length(word), fn(x) -> "_" end)
  end

  @doc """

  `{game, status} = make_move(game, guess)`

   Accept a guess. Return a tuple containing the updated
   game state and a map containing the game's status at the end of the move.


         last_guess:  # the last character guessed
         game_state:  # :in_progress, :lost, or :won
         guess_state: # :good_guess, :bad_guess, or :already_guessed
         turns_left:  # the number of turns remaining
         guessed:     # a list of the letters already guessed
         letters:     # a list of single character strings representing
                      # the word to guess. Letters in the word that have
                      # been previously guessed correctly are shown as
                      # themselves. Letters that still have to be
                      # guessed are shown as underscores.
  """

  @spec make_move(game, ch) :: { game, status }

  def make_move(status, guess) do
    status
    |> update_last_guess(guess)
    |> check_already_guessed
    |> maybe_set_already_guessed
    |> update_state

    # check to see if the letter has already been used, returning
    # the :already_guessed status in guess_state if so
    #
    # otherwise record the move, and work out if the guess
    # was good or bad. If good, also work out if the game is
    # now won. If bad, check to see if it is lost
    #
  end

  def update_state(%{guess_state: :already_guessed} = status, _word) do
    status
  end

  def update_state(status) do
    status
    |> check_guess_validity(status.word)
    |> set_valid_guess_status
    |> update_guessed
    |> update_turns
    |> update_game_state
  end

  def update_guessed(%{guess_state: :already_guessed} = status) do
    status
  end

  def update_guessed(%{guess_state: guess_state} = status) do
    %{status | guessed: [status.last_guess | status.guessed]}
  end

  def check_if_lost(%{turns_left: 0} = status) do
    %{status | game_state: :lost}
  end

  def check_if_lost(status) do
    status
  end

  def update_game_state(%{guess_state: :bad_guess} = status) do
    status
    |> check_if_lost
  end

  def update_game_state(%{guess_state: :good_guess} = status) do
    status
    |> update_word
    |> update_letters
    |> check_if_won
  end

  def check_if_won(status) do
    winner_winner_chicken_dinner?(status)
    |> maybe_set_won_state
  end

  def maybe_set_won_state({status, winner=true}) do
    %{status | game_state: :won}
  end

  def maybe_set_won_state({status, _not_won}) do
    status
  end

  def winner_winner_chicken_dinner?(%{letters: letters} = status) do
    {status, Enum.member?(letters, "_")}
  end

  def update_word(status) do
    word = status.word
    |> Enum.map(fn{k,v} -> {k, (v || (k == status.last_guess))} end)

    IEx.pry

    %{status | word: word}
  end

  def update_letters(status) do
    letters = status.word
    |> Enum.map(fn{k, v} -> display_value(k,v) end)

    %{status | letters: letters}
  end

  def display_value(letter, displayed = true), do: letter

  def display_value(_letter, _not_displayed), do: "_"

  def update_turns(%{guess_state: :good_guess} = status) do
    status
  end

  def update_turns(%{turns_left: turns, guess_state: :bad_guess} = status) do
    %{status | turns_left: turns - 1}
  end

  def set_valid_guess_status({status, _good_guess = true}) do
    %{status | guess_state: :good_guess}
  end

  def set_valid_guess_status({status, _bad_guess}) do
    %{status | guess_state: :bad_guess}
  end

  def check_guess_validity(status, word) do
    {status, valid_guess?(status, word)}
  end

  def valid_guess?(%{last_guess: last_guess}, word) do
    word
    |> Enum.map(fn{k,v} -> k end)
    |> Enum.member?(last_guess)
  end

  def maybe_set_already_guessed({status, true}) do
    %{status | guess_state: :already_guessed}
  end

  def maybe_set_already_guessed({status, _not_already_guessed}) do
    status
  end

  def update_last_guess(status, guess) do
    %{status | last_guess: guess}
  end

  def check_already_guessed(status) do
    {status, already_guessed?(status.guessed, status.last_guess)}
  end

  def already_guessed?(guessed, guess) do
    Enum.member?(guessed, guess)
  end

  @doc """
  Return the status of game. See `make_move` for the format.
  """
  @spec get_status(game) :: status
  def get_status(game) do
    # ...
  end


  @doc """
  Return a fresh game, discarding the previous state of `game`
  """
  @spec reset_game(game) :: game
  def reset_game(_game) do
    # ...
  end


  ###########################
  # end of public interface #
  ###########################

  # Your helper functions go here.
end
