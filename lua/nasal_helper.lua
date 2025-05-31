
function nasal_processor(inp, seg, env)

  local config = env.engine.schema.config
  config:set_string('translator/input_str', inp)
  
  env.input_str = config:get_string('translator/input_str')

  env.keep_comment = config:get_bool('translator/keep_comments')

  return inp
end

-- Export the filter function
return nasal_processor