#!/bin/bash

output_dir=.

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    exit 1
elif [ $# -eq 2 ]
  then
    output_dir=$2
fi

if [ ! -d "$output_dir" ]; then
  mkdir $output_dir
fi

# Set the name of the template file
template="$1.tex"

pdflatex $template

# Get the preamble from the template file
preamble=$(awk '/^\\begin{document}/ {exit} {print}' "${template}")

echo $preamble

# Loop through each line in the input file
while read -r varname; do
  # Set the name of the output file
  output="$output_dir/${varname}.tex"

  # Copy the contents of the template file to the output file
  echo "${preamble}" > "${output}"

  # Print the document block to the output file
  echo "\begin{document}" >> "${output}"
  echo "\\$varname" >> "${output}"
  echo "\end{document}" >> "${output}"
  pdflatex -output-directory $output_dir $output
  # Remove the output file
  rm $output $output_dir/$varname.aux $output_dir/$varname.exports $output_dir/$varname.log
done < $1.exports