#!lleval
[1..30].map({
      { $^n % 3 ?? '' !! 'Fizz' }($_)
        ~
          { $^n % 5 ?? '' !! 'Buzz' }($_)
            || $_
}).join("\n").say;

