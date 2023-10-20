#!/bin/bash

# Set the name of the template file
template="$1.tex"

pdflatex $template

# Get the preamble from the template file
preamble=$(awk '/^\\begin{document}/ {exit} {print}' "${template}")

echo $preamble

# Loop through each line in the input file
while read -r varname; do
  # Set the name of the output file
  output="${varname}.tex"

  # Copy the contents of the template file to the output file
  echo "${preamble}" > "${output}"

  # Print the document block to the output file
  echo "\begin{document}" >> "${output}"
  echo "\\$varname" >> "${output}"
  echo "\end{document}" >> "${output}"
  pdflatex $output
  # Remove the output file
  rm $output $varname.aux $varname.exports $varname.log
done < $1.exports