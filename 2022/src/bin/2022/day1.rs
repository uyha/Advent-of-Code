use std::fs;
use std::io::{BufRead, BufReader};

fn main() {
    let file = fs::File::open("data/2022/day1").unwrap();
    let lines = BufReader::new(file).lines();

    let mut calories = vec![];
    let mut current = 0;

    for line in lines {
        let line = line.unwrap();
        if line != "" {
            current += str::parse::<i32>(&line).unwrap();
        } else {
            calories.push(current);
            current = 0;
        }
    }
    calories.sort_by(|lhs, rhs| rhs.cmp(lhs));
    println!("{:?}", calories);
    println!("{:?}", calories[..3].iter().sum::<i32>());
}
