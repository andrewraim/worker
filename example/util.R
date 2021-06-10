printf = function(msg, ...)
{
	cat(sprintf(msg, ...))
}

logger = function(msg, ...)
{
	sys.time = as.character(Sys.time())
	cat(sys.time, "-", sprintf(msg, ...))
}

print_vector = function(x)
{
	sprintf("c(%s)", paste(x, collapse = ","))
}
