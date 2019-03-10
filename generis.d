/*
    This file is part of the generis distribution.

    https://github.com/senselogic/generis

    Copyright (C) 2017 Eric Pelzer (ecstatic.coder@gmail.com)

    generis is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    generis is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with generis.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import core.thread;
import std.conv : to;
import std.datetime : Clock, SysTime;
import std.file : dirEntries, exists, mkdirRecurse, readText, timeLastModified, write, FileException, SpanMode;
import std.path : dirName;
import std.stdio : writeln;
import std.string : endsWith, indexOf, join, replace, split, startsWith, strip, stripLeft, stripRight, toUpper;

// -- TYPES

enum TOKEN_CONTEXT
{
    None,
    ShortComment,
    LongComment,
    StringLiteral
}

// ~~

enum TOKEN_TYPE
{
    None,
    Blank,
    Identifier,
    Parameter
}

// ~~

class TOKEN
{
    // -- ATTRIBUTES

    string
        Text;
    TOKEN_CONTEXT
        Context;
    TOKEN_TYPE
        Type;

    // -- CONSTRUCTORS

    this(
        string text = "",
        TOKEN_CONTEXT token_context = TOKEN_CONTEXT.None,
        TOKEN_TYPE token_type = TOKEN_TYPE.None
        )
    {
        Text = text;
        Context = token_context;
        Type = token_type;
    }

    // ~~

    this(
        char character,
        TOKEN_CONTEXT token_context = TOKEN_CONTEXT.None,
        TOKEN_TYPE token_type = TOKEN_TYPE.None
        )
    {
        Text ~= character;
        Context = token_context;
        Type = token_type;
    }

    // -- INQUIRIES

    bool IsBlank(
        )
    {
        return Type == TOKEN_TYPE.Blank;
    }

    // ~~

    bool IsIdentifier(
        )
    {
        return Type == TOKEN_TYPE.Identifier;
    }

    // ~~

    bool IsParameter(
        )
    {
        return Type == TOKEN_TYPE.Parameter;
    }

    // ~~

    bool Matches(
        TOKEN token
        )
    {
        if ( Type == TOKEN_TYPE.Blank )
        {
            return token.Type == TOKEN_TYPE.Blank;
        }
        else
        {
            return token.Text == Text;
        }
    }

    // ~~

    string GetParameterName(
        )
    {
        return Text[ 2 .. $ - 2 ].split( ":" )[ 0 ];
    }

    // ~~

    void Dump(
        long token_index
        )
    {
        writeln( "[", token_index, "] ", Context, " ", Type, " : ", Text );
    }
}

// ~~

class CODE
{
    // -- ATTRIBUTES

    TOKEN[]
        TokenArray;

    // -- CONSTRUCTORS

    this(
        TOKEN[] token_array
        )
    {
        TokenArray = token_array;
    }

    // ~~

    this(
        string text,
        bool parameters_are_parsed
        )
    {
        SetFromText( text, parameters_are_parsed );
    }

    // -- INQUIRIES

    string GetText(
        )
    {
        string
            text;

        foreach ( token; TokenArray )
        {
            text ~= token.Text;
        }

        return text;
    }

    // ~~

    void Dump(
        )
    {
        foreach( token_index, token; TokenArray )
        {
            token.Dump( token_index );
        }
    }

    // -- OPERATIONS

    void AddToken(
        TOKEN token
        )
    {
        if ( token.Text.length > 0 )
        {
            TokenArray ~= token;
        }
    }

    // ~~

    void AddTokenArray(
        TOKEN token,
        bool parameters_are_parsed
        )
    {
        char
            character;
        long
            character_index;
        string
            text;
        TOKEN_CONTEXT
            token_context;

        text = token.Text;
        token_context = token.Context;

        if ( text.length > 0 )
        {
            token = new TOKEN( "", token_context );

            for ( character_index = 0;
                  character_index < text.length;
                  ++character_index )
            {
                character = text[ character_index ];

                if ( token.IsBlank()
                     && character.IsBlankCharacter() )
                {
                    token.Text ~= character;
                }
                else if ( token.IsIdentifier()
                          && character.IsIdentifierCharacter() )
                {
                    token.Text ~= character;
                }
                else if ( token.IsParameter()
                          && character == '}'
                          && character_index + 1 < text.length
                          && text[ character_index + 1 ] == '}' )
                {
                    token.Text ~= "}}";

                    AddToken( token );

                    ++character_index;

                    token = new TOKEN( "", token_context );
                }
                else if ( token.IsParameter() )
                {
                    token.Text ~= character;
                }
                else if ( character.IsBlankCharacter() )
                {
                    AddToken( token );

                    token = new TOKEN( character, token_context, TOKEN_TYPE.Blank );
                }
                else if ( character.IsIdentifierCharacter() )
                {
                    AddToken( token );

                    token = new TOKEN( character, token_context, TOKEN_TYPE.Identifier );
                }
                else if ( parameters_are_parsed
                          && character == '{'
                          && character_index + 1 < text.length
                          && text[ character_index + 1 ] == '{' )
                {
                    AddToken( token );

                    token = new TOKEN( "{{", token_context, TOKEN_TYPE.Parameter );

                    ++character_index;
                }
                else
                {
                    AddToken( token );

                    token = new TOKEN( character, token_context );
                }
            }

            AddToken( token );
        }
    }

    // ~~

    void SetFromText(
        string text,
        bool parameters_are_parsed
        )
    {
        char
            character,
            delimiter_character;
        long
            character_index;
        TOKEN
            token;

        TokenArray = null;

        token = new TOKEN();

        for ( character_index = 0;
              character_index < text.length;
              ++character_index )
        {
            character = text[ character_index ];

            if ( token.Context == TOKEN_CONTEXT.ShortComment )
            {
                if ( character == '\n' )
                {
                    AddTokenArray( token, parameters_are_parsed );

                    token = new TOKEN( "\n" );
                }
                else
                {
                    token.Text ~= character;
                }
            }
            else if ( token.Context == TOKEN_CONTEXT.LongComment )
            {
                if ( character == '*'
                     && character_index + 1 < text.length
                     && text[ character_index + 1 ] == '/' )
                {
                    AddTokenArray( token, parameters_are_parsed );

                    token = new TOKEN( "*/", TOKEN_CONTEXT.LongComment );
                    AddToken( token );

                    token = new TOKEN( "" );

                    ++character_index;
                }
                else
                {
                    token.Text ~= character;
                }
            }
            else if ( token.Context == TOKEN_CONTEXT.StringLiteral )
            {
                if ( character == delimiter_character )
                {
                    AddTokenArray( token, parameters_are_parsed );

                    token = new TOKEN( delimiter_character, token.Context );
                    AddToken( token );

                    token = new TOKEN( "" );
                }
                else if ( character == '\\'
                          && character + 1 < text.length )
                {
                    AddTokenArray( token, parameters_are_parsed );

                    token = new TOKEN( text[ character_index .. character_index + 2 ], TOKEN_CONTEXT.StringLiteral );
                    AddToken( token );

                    token = new TOKEN( "", TOKEN_CONTEXT.StringLiteral );

                    ++character_index;
                }
                else
                {
                    token.Text ~= character;
                }
            }
            else if ( character == '/'
                      && character_index + 1 < text.length
                      && text[ character_index + 1 ] == '/' )
            {
                AddTokenArray( token, parameters_are_parsed );

                token = new TOKEN( "//", TOKEN_CONTEXT.ShortComment );
                AddToken( token );

                token = new TOKEN( "", TOKEN_CONTEXT.ShortComment );

                ++character_index;
            }
            else if ( character == '/'
                      && character_index + 1 < text.length
                      && text[ character_index + 1 ] == '*' )
            {
                AddTokenArray( token, parameters_are_parsed );

                token = new TOKEN( "/*", TOKEN_CONTEXT.LongComment );
                AddToken( token );

                token = new TOKEN( "", TOKEN_CONTEXT.LongComment );
                ++character_index;
            }
            else if ( character == '\''
                      || character == '"'
                      || character == '`' )
            {
                AddTokenArray( token, parameters_are_parsed );

                delimiter_character = character;

                token = new TOKEN( delimiter_character, TOKEN_CONTEXT.StringLiteral );
                AddToken( token );

                token = new TOKEN( "", TOKEN_CONTEXT.StringLiteral );
            }
            else
            {
                token.Text ~= character;
            }
        }

        AddTokenArray( token, parameters_are_parsed );
    }

    // ~~

    bool ReplaceDefinitions(
        )
    {
        bool
            match_was_found,
            code_has_changed;
        long
            token_index;
        MATCH
            match;

        code_has_changed = false;

        do
        {
            match_was_found = false;

            for ( token_index = 0;
                  token_index < TokenArray.length;
                  ++token_index )
            {
                match = null;

                foreach ( definition; DefinitionArray )
                {
                    match = definition.GetMatch( TokenArray, token_index );

                    if ( match !is null )
                    {
                        TokenArray
                            = TokenArray[ 0 .. token_index ]
                              ~ match.NewTokenArray
                              ~ TokenArray[ token_index + match.OldTokenArray.length .. $ ];

                        break;
                    }
                }

                if ( match !is null )
                {
                    match_was_found = true;
                    code_has_changed = true;

                    --token_index;
                }
            }
        }
        while ( match_was_found );

        return code_has_changed;
    }
}

// ~~

class MATCH
{
    // -- ATTRIBUTES

    TOKEN[]
        OldTokenArray,
        NewTokenArray;
    CODE[ string ]
        ParameterCodeMap;

    // -- INQUIRIES

    bool HasParameter(
        string parameter_name
        )
    {
        return ( parameter_name in ParameterCodeMap ) !is null;
    }
}

// ~~

class DEFINITION
{
    // -- ATTRIBUTES

    string[]
        OldLineArray,
        NewLineArray;
    CODE
        OldCode,
        NewCode;
    TOKEN[]
        OldTokenArray,
        NewTokenArray;

    // -- INQUIRIES

    MATCH GetMatch(
        TOKEN[] token_array,
        long token_index
        )
    {
        long
            matched_token_count,
            matched_token_index,
            next_old_token_index,
            next_token_index,
            old_token_index;
        string
            parameter_name;
        CODE
            parameter_code;
        MATCH
            match;
        TOKEN
            next_old_token,
            next_token,
            old_token,
            token;
        TOKEN[]
            matched_token_array;

        match = new MATCH();

        old_token_index = 0;

        while ( old_token_index < OldTokenArray.length
                && token_index < token_array.length )
        {
            old_token = OldTokenArray[ old_token_index ];
            token = token_array[ token_index ];

            if ( old_token.IsParameter() )
            {
                next_old_token_index = old_token_index + 1;

                matched_token_count = 0;

                while ( next_old_token_index + matched_token_count < OldTokenArray.length
                        && !OldTokenArray[ next_old_token_index + matched_token_count ].IsParameter() )
                {
                    ++matched_token_count;
                }

                matched_token_index = 0;
                next_token_index = token_index;

                while ( next_token_index < token_array.length )
                {
                    matched_token_index = 0;

                    while ( matched_token_index < matched_token_count
                            && next_token_index + matched_token_index < token_array.length
                            && next_old_token_index + matched_token_index < OldTokenArray.length )
                    {
                        next_token = token_array[ next_token_index + matched_token_index ];
                        next_old_token = OldTokenArray[ next_old_token_index + matched_token_index ];

                        if ( next_token.Matches( next_old_token ) )
                        {
                            ++matched_token_index;
                        }
                        else
                        {
                            break;
                        }
                    }

                    if ( matched_token_index == matched_token_count )
                    {
                        break;
                    }
                    else
                    {
                        ++next_token_index;
                    }
                }

                if ( matched_token_index == matched_token_count )
                {
                    parameter_name = old_token.GetParameterName();

                    if ( match.HasParameter( parameter_name ) )
                    {
                        writeln( OldCode.GetText() );

                        Abort( "Duplicate parameter : {{" ~ parameter_name ~ "}}" );
                    }

                    matched_token_array = token_array[ token_index .. next_token_index ];

                    match.OldTokenArray ~= matched_token_array;
                    match.ParameterCodeMap[ parameter_name ] = new CODE( matched_token_array );

                    old_token_index = next_old_token_index;
                    token_index = next_token_index;
                }
                else
                {
                    return null;
                }
            }
            else if ( token.Matches( old_token ) )
            {
                match.OldTokenArray ~= token;

                ++old_token_index;
                ++token_index;
            }
            else
            {
                return null;
            }
        }

        if ( old_token_index == OldTokenArray.length )
        {
            foreach ( new_token; NewTokenArray )
            {
                if ( new_token.IsParameter() )
                {
                    parameter_name = new_token.GetParameterName();

                    if ( !match.HasParameter( parameter_name ) )
                    {
                        writeln( OldCode.GetText() );
                        writeln( NewCode.GetText() );

                        Abort( "Missing parameter : {{" ~ parameter_name ~ "}}" );
                    }

                    parameter_code = match.ParameterCodeMap[ parameter_name ];

                    match.NewTokenArray ~= parameter_code.TokenArray;
                }
                else
                {
                    match.NewTokenArray ~= new_token;
                }
            }

            return match;
        }
        else
        {
            return null;
        }
    }

    // ~~

    void Dump(
        )
    {
        writeln( OldCode.GetText() );
        writeln( NewCode.GetText() );
    }

    // -- OPERATIONS

    void Parse(
        )
    {
        OldCode = new CODE( OldLineArray.join( '\n' ), true );
        NewCode = new CODE( NewLineArray.join( '\n' ), true );

        OldTokenArray = OldCode.TokenArray;
        NewTokenArray = NewCode.TokenArray;
    }
}

// ~~

class FILE
{
    // -- ATTRIBUTES

    string
        InputPath,
        OutputPath;
    bool
        Exists,
        HasChanged,
        IsProcessed;
    SysTime
        SystemTime;
    bool
        UsesCarriageReturn;
    string
        Text;
    string[]
        LineArray;

    // -- CONSTRUCTORS

    this(
        string input_file_path,
        string output_file_path
        )
    {
        InputPath = input_file_path;
        OutputPath = output_file_path;
        Exists = true;
        HasChanged = true;
        IsProcessed = true;
    }

    // -- INQUIRIES

    void AbortFile(
        string message
        )
    {
        Abort( "[" ~ InputPath ~ "] " ~ message );
    }

    // -- OPERATIONS

    void CheckChange(
        bool modification_time_is_used
        )
    {
        SysTime
            old_system_time;

        if ( modification_time_is_used )
        {
            HasChanged = true;
        }
        else
        {
            old_system_time = SystemTime;
            SystemTime = InputPath.timeLastModified();
            HasChanged = ( SystemTime > old_system_time );
        }

        IsProcessed
            = ( HasChanged
                || ( OutputPath != ""
                     && ( !OutputPath.exists()
                          || InputPath.timeLastModified() > OutputPath.timeLastModified() ) ) );
    }

    // ~~

    void ReadInputFile(
        )
    {
        if ( HasChanged )
        {
            writeln( "Reading file : ", InputPath );

            try
            {
                Text = InputPath.readText();
            }
            catch ( FileException file_exception )
            {
                Abort( "Can't read file : " ~ InputPath, file_exception );
            }

            UsesCarriageReturn = ( Text.indexOf( '\r' ) >= 0 );

            if ( UsesCarriageReturn )
            {
                Text = Text.replace( "\r", "" );
            }

            Text = Text.replace( "\t", GetSpaceText( TabulationSpaceCount ) );
        }

        LineArray = null;
    }

    // ~~

    void ParseDefinitions(
        )
    {
        long
            command_space_count,
            level,
            line_index,
            space_count,
            state;
        string
            line,
            stripped_line;
        string[]
            line_array;
        DEFINITION
            definition;

        LineArray = Text.split( '\n' );

        for ( line_index = 0;
              line_index < LineArray.length;
              ++line_index )
        {
            line = LineArray[ line_index ].stripRight();
            stripped_line = line.stripLeft();

            if ( stripped_line == "#define"
                 || stripped_line.startsWith( "#define " ) )
            {
                command_space_count = GetSpaceCount( line );

                ++line_index;

                definition = new DEFINITION();

                if ( stripped_line.startsWith( "#define " ) )
                {
                    definition.OldLineArray ~= stripped_line[ 8 .. $ ].strip();
                }

                while ( line_index < LineArray.length )
                {
                    line = LineArray[ line_index ].stripRight();
                    stripped_line = line.stripLeft();

                    if ( stripped_line == "#as"
                         || stripped_line.startsWith( "#as " ) )
                    {
                        break;
                    }
                    else
                    {
                        definition.OldLineArray ~= line.RemoveSpaceCount( command_space_count + TabulationSpaceCount );
                    }

                    ++line_index;
                }

                if ( line_index == LineArray.length )
                {
                    Dump( LineArray );

                    AbortFile( "Missing #as for #define" );
                }

                ++line_index;


                if ( stripped_line.startsWith( "#as " ) )
                {
                    definition.NewLineArray ~= stripped_line[ 4 .. $ ].strip();
                }
                else
                {
                    command_space_count = GetSpaceCount( line );

                    level = 0;

                    while ( line_index < LineArray.length )
                    {
                        line = LineArray[ line_index ].stripRight();
                        stripped_line = line.stripLeft();

                        if ( stripped_line.IsOpeningCommand() )
                        {
                            ++level;
                        }

                        if ( stripped_line == "#end"
                             && level == 0 )
                        {
                            break;
                        }
                        else
                        {
                            definition.NewLineArray ~= line.RemoveSpaceCount( command_space_count + TabulationSpaceCount );

                            if ( stripped_line == "#end" )
                            {
                                --level;
                            }
                        }

                        ++line_index;
                    }

                    if ( line_index == LineArray.length )
                    {
                        Dump( LineArray );

                        AbortFile( "Missing #end for #define" );
                    }
                }

                definition.Parse();

                DefinitionArray ~= definition;
            }
            else
            {
                line_array ~= line;
            }
        }

        LineArray = line_array;
    }

    // ~~

    void ApplyDefinitions(
        )
    {
        CODE
            code;

        code = new CODE( LineArray.join( '\n' ), false );

        if ( code.ReplaceDefinitions() )
        {
            LineArray = code.GetText().split( '\n' );
        }
    }

    // ~~

    void ApplyConditions(
        )
    {
        bool
            condition;
        long
            end_line_index,
            level,
            line_index;
        string
            line,
            stripped_line;
        string[]
            condition_line_array;

        for ( line_index = 0;
              line_index < LineArray.length;
              ++line_index )
        {
            line = LineArray[ line_index ].stripRight();
            stripped_line = line.stripLeft();

            if ( stripped_line.startsWith( "#if " ) )
            {
                condition = stripped_line[ 4 .. $ ].EvaluateBooleanExpression();
                level = 0;

                end_line_index = line_index + 1;

                condition_line_array = null;

                while ( end_line_index < LineArray.length )
                {
                    line = LineArray[ end_line_index ].stripRight();
                    stripped_line = line.stripLeft();

                    if ( stripped_line.IsOpeningCommand() )
                    {
                        ++level;
                    }

                    if ( stripped_line == "#end"
                         && level == 0 )
                    {
                        break;
                    }
                    else
                    {
                        if ( stripped_line == "#else"
                             && level == 0 )
                        {
                            condition = !condition;
                        }
                        else if ( condition )
                        {
                            condition_line_array ~= line.RemoveSpaceCount( TabulationSpaceCount );
                        }

                        if ( stripped_line == "#end" )
                        {
                            --level;
                        }
                    }

                    ++end_line_index;
                }

                if ( end_line_index == LineArray.length )
                {
                    Dump( LineArray );

                    AbortFile( "Missing #end for #if" );
                }

                LineArray
                    = LineArray[ 0 .. line_index ]
                      ~ condition_line_array
                      ~ LineArray[ end_line_index + 1 .. $ ];

                --line_index;
            }
        }
    }

    // ~~

    string GetTemplateText(
        string[] template_line_array,
        string writer_expression,
        long space_count
        )
    {
        char
            character,
            next_character;
        long
            character_index,
            first_character_index,
            state;
        string
            empty_string_writer_line,
            string_writer_prefix,
            string_writer_suffix,
            text,
            writer_prefix,
            writer_suffix,
            writer_text;
        string[]
            writer_line_array;

        if ( template_line_array.length > 0 )
        {
            writer_prefix = GetSpaceText( space_count ) ~ "io.WriteString( " ~ writer_expression ~ ", ";
            writer_suffix = " );";

            string_writer_prefix = writer_prefix ~ "\"";
            string_writer_suffix = "\"" ~ writer_suffix;

            text = template_line_array.join( '\n' );
            writer_line_array ~= string_writer_prefix;

            for ( character_index = 0;
                  character_index < text.length;
                  ++character_index )
            {
                character = text[ character_index ];

                if ( character_index + 2 < text.length
                     && character == '<'
                     && text[ character_index + 1 ] == '%'
                     && text[ character_index + 2 ] != '!' )
                {
                    writer_line_array[ $ - 1 ] ~= string_writer_suffix;

                    character_index += 2;

                    first_character_index = character_index;

                    while ( character_index < text.length )
                    {
                        if ( text[ character_index ] == '%'
                             && character_index + 1 < text.length
                             && text[ character_index + 1 ] == '>' )
                        {
                            break;
                        }
                        else
                        {
                            ++character_index;
                        }
                    }

                    if ( character_index == text.length )
                    {
                        writeln( text );

                        AbortFile( "Missing %>" );
                    }

                    writer_text = text[ first_character_index .. character_index ];

                    ++character_index;

                    if ( writer_text.startsWith( '@' ) )
                    {
                        writer_line_array
                            ~= writer_prefix
                               ~ "strconv.FormatUint( uint64( "
                               ~ writer_text[ 1 .. $ ].strip()
                               ~ " ), 10 )"
                               ~ writer_suffix;
                    }
                    else if ( writer_text.startsWith( '#' ) )
                    {
                        writer_line_array
                            ~= writer_prefix
                               ~ "strconv.FormatInt( int64( "
                               ~ writer_text[ 1 .. $ ].strip()
                               ~ " ), 10 )"
                               ~ writer_suffix;
                    }
                    else if ( writer_text.startsWith( '&' ) )
                    {
                        writer_line_array
                            ~= writer_prefix
                               ~ "strconv.FormatFloat( float64( "
                               ~ writer_text[ 1 .. $ ].strip()
                               ~ " ), 'f', -1, 64 )"
                               ~ writer_suffix;
                    }
                    else if ( writer_text.startsWith( '=' ) )
                    {
                        writer_line_array
                            ~= writer_prefix
                               ~ writer_text[ 1 .. $ ].strip()
                               ~ writer_suffix;
                    }
                    else if ( writer_text.startsWith( '~' ) )
                    {
                        writer_line_array
                            ~= writer_prefix
                               ~ "html.EscapeString( "
                               ~ writer_text[ 1 .. $ ].strip()
                               ~ " )"
                               ~ writer_suffix;
                    }
                    else
                    {
                        writer_line_array ~= writer_text;
                    }

                    writer_line_array ~= string_writer_prefix;
                }
                else
                {
                    if ( character == '"' )
                    {
                        writer_line_array[ $ - 1 ] ~= "\\\"";
                    }
                    else if ( character == '\n' )
                    {
                        writer_line_array[ $ - 1 ] ~= "\\n";
                    }
                    else
                    {
                        writer_line_array[ $ - 1 ] ~= character;
                    }
                }
            }

            writer_line_array[ $ - 1 ] ~= string_writer_suffix;
        }

        empty_string_writer_line = string_writer_prefix ~ string_writer_suffix;
        template_line_array = null;

        foreach ( writer_line; writer_line_array )
        {
            if ( writer_line != empty_string_writer_line )
            {
                template_line_array ~= writer_line;
            }
        }

        return template_line_array.join( '\n' ).replace( "<\\%", "<%" ).replace( "%\\>", "%>" );
    }

    // ~~

    void ApplyTemplates(
        )
    {
        long
            line_index,
            space_count;
        string
            line,
            stripped_line,
            template_text,
            writer_expression;
        string[]
            line_array,
            template_line_array;

        for ( line_index = 0;
              line_index < LineArray.length;
              ++line_index )
        {
            line = LineArray[ line_index ].stripRight();
            stripped_line = line.stripLeft();

            if ( stripped_line.startsWith( "#write " ) )
            {
                writer_expression = stripped_line[ 7 .. $ ].strip();

                if ( writer_expression == "" )
                {
                    Dump( LineArray[ 0 .. line_index ] );

                    AbortFile( "Missing writer expression" );
                }

                ++line_index;

                space_count = GetSpaceCount( line );

                while ( line_index < LineArray.length )
                {
                    line = LineArray[ line_index ].stripRight().RemoveSpaceCount( space_count + TabulationSpaceCount );
                    stripped_line = line.stripLeft();

                    if ( stripped_line == "#end" )
                    {
                        break;
                    }
                    else
                    {
                        template_line_array ~= line;
                    }

                    ++line_index;
                }

                if ( line_index == LineArray.length )
                {
                    Dump( LineArray );

                    AbortFile( "Missing #end for #write" );
                }

                template_text = GetTemplateText( template_line_array, writer_expression, space_count );

                line_array ~= template_text;
            }
            else
            {
                line_array ~= line;
            }
        }

        LineArray = line_array;
    }

    // ~~

    void SplitLines(
        )
    {
        long
            line_index;

        LineArray = LineArray.join( '\n' ).split( '\n' );

        for ( line_index = 0;
              line_index < LineArray.length;
              ++line_index )
        {
            LineArray[ line_index ] = LineArray[ line_index ].stripRight();
        }
    }

    // ~~

    void JoinStatements(
        )
    {
        char
            line_first_character,
            line_last_character,
            next_line_first_character,
            prior_line_last_character;
        long
            line_index;
        string
            line,
            line_first_characters,
            next_stripped_line,
            prior_stripped_line,
            stripped_line;

        if ( JoinOptionIsEnabled )
        {
            SplitLines();

            line_index = 0;

            while ( line_index < LineArray.length )
            {
                line = LineArray[ line_index ];
                stripped_line = line.strip();

                if ( stripped_line != "" )
                {
                    line_first_character = stripped_line[ 0 ];

                    if ( stripped_line.length >= 2 )
                    {
                        line_first_characters = stripped_line[ 0 .. 2 ];
                    }
                    else
                    {
                        line_first_characters = stripped_line[ 0 .. 1 ];
                    }

                    line_last_character = stripped_line[ $ - 1 ];

                    if ( line_index > 0
                         && "{)]+-*/%&|^<>=!:.".indexOf( line_first_character ) >= 0
                         && line_first_characters != "--"
                         && line_first_characters != "++"
                         && line_first_characters != "/*"
                         && line_first_characters != "*/"
                         && line_first_characters != "//" )
                    {
                        prior_stripped_line = stripRight( LineArray[ line_index - 1 ] );

                        if ( prior_stripped_line.length > 0 )
                        {
                            prior_line_last_character = prior_stripped_line[ $ - 1 ];
                        }
                        else
                        {
                            prior_line_last_character = 0;
                        }

                        if ( !HasEndingComment( prior_stripped_line )
                             && prior_stripped_line != ""
                             && ( "{};".indexOf( prior_line_last_character ) < 0
                                  || ( prior_line_last_character == '}'
                                       && ")]".indexOf( line_first_character ) >= 0 ) ) )
                        {
                            LineArray[ line_index - 1 ] = prior_stripped_line ~ " " ~ stripped_line;
                            LineArray = LineArray[ 0 .. line_index ] ~ LineArray[ line_index + 1 .. $ ];

                            --line_index;

                            continue;
                        }
                    }

                    if ( line_index + 1 < LineArray.length )
                    {
                        next_stripped_line = LineArray[ line_index + 1 ].strip();

                        if ( next_stripped_line.length > 0 )
                        {
                            next_line_first_character = next_stripped_line[ 0 ];
                        }
                        else
                        {
                            next_line_first_character = 0;
                        }

                        if ( "([,".indexOf( line_last_character ) >= 0
                             || ( line_first_characters != "//"
                                  && "};,".indexOf( line_last_character ) < 0
                                  && next_line_first_character == '}' )
                             || stripped_line == "return"
                             || stripped_line == "var"
                             || ( stripped_line == "}"
                                  && ( next_stripped_line == "else"
                                       || next_stripped_line.startsWith( "else " ) ) ) )
                        {
                            stripped_line = stripRight( LineArray[ line_index ] );

                            if ( !HasEndingComment( stripped_line ) )
                            {
                                LineArray[ line_index ] = stripped_line ~ " " ~ next_stripped_line;
                                LineArray = LineArray[ 0 .. line_index + 1 ] ~ LineArray[ line_index + 2 .. $ ];

                                continue;
                            }
                        }
                    }
                }

                ++line_index;
            }
        }
    }

    // ~~

    void CreateOutputFolder(
        )
    {
        string
            output_folder_path;

        output_folder_path = OutputPath.dirName();

        if ( !output_folder_path.exists() )
        {
            writeln( "Creating folder : ", output_folder_path );

            try
            {
                if ( output_folder_path != ""
                     && output_folder_path != "/"
                     && !output_folder_path.exists() )
                {
                    output_folder_path.mkdirRecurse();
                }
            }
            catch ( FileException file_exception )
            {
                Abort( "Can't create folder : " ~ output_folder_path, file_exception );
            }
        }
    }

    // ~~

    void WriteOutputFile(
        )
    {
        string
            output_text;

        if ( CreateOptionIsEnabled )
        {
            CreateOutputFolder();
        }

        writeln( "Writing file : ", OutputPath );

        if ( UsesCarriageReturn )
        {
            output_text = LineArray.join( "\r\n" );
        }
        else
        {
            output_text = LineArray.join( "\n" );
        }

        try
        {
            OutputPath.write( output_text );
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't write file : " ~ OutputPath, file_exception );
        }
    }
}

// -- VARIABLES

bool
    CreateOptionIsEnabled,
    JoinOptionIsEnabled,
    WatchOptionIsEnabled;
string
    SpaceText;
string[]
    InputFolderPathArray,
    OutputFolderPathArray;
long
    PauseDuration,
    TabulationSpaceCount;
FILE[ string ]
    FileMap;
DEFINITION[]
    DefinitionArray;

// -- FUNCTIONS

void PrintError(
    string message
    )
{
    writeln( "*** ERROR : ", message );
}

// ~~

void Abort(
    string message
    )
{
    PrintError( message );

    exit( -1 );
}

// ~~

void Abort(
    string message,
    FileException file_exception
    )
{
    PrintError( message );
    PrintError( file_exception.msg );

    exit( -1 );
}

// ~~

void Dump(
    string[] line_array
    )
{
    writeln( line_array.join( '\n' ) );
}

// ~~

bool IsBlankCharacter(
    char character
    )
{
    return
        character == ' '
        || character == '\t'
        || character == '\r'
        || character == '\n';
}

// ~~

bool IsIdentifierCharacter(
    char character
    )
{
    return
        ( character >= 'a' && character <= 'z' )
        || ( character >= 'A' && character <= 'Z' )
        || ( character >= '0' && character <= '9' )
        || character == '_';
}

// ~~

bool IsOpeningCharacter(
    char character
    )
{
    return
        character == '{'
        || character == '['
        || character == '(';
}

// ~~

bool IsOpeningCharacter(
    char character
    )
{
    return
        character == '}'
        || character == ']'
        || character == ')';
}

// ~~

long GetSpaceCount(
    string text
    )
{
    long
        space_count;

    space_count = 0;

    while ( space_count < text.length
            && text[ space_count ] == ' ' )
    {
        ++space_count;
    }

    return space_count;
}

// ~~

string RemoveSpaceCount(
    string text,
    long space_count
    )
{
    long
        space_index;

    while ( space_index < space_count
            && space_index < text.length
            && text[ space_index ] == ' ' )
    {
        ++space_index;
    }

    return text[ space_index .. $ ];
}

// ~~

string GetSpaceText(
    long space_count
    )
{
    if ( space_count <= 0 )
    {
        return "";
    }
    else
    {
        while ( SpaceText.length < space_count )
        {
            SpaceText ~= SpaceText;
        }

        return SpaceText[ 0 .. space_count ];
    }
}

// ~~

string GetLogicalPath(
    string path
    )
{
    return path.replace( "\\", "/" );
}

// ~~

string[] GetWordArray(
    string text,
    string separator
    )
{
    char
        character,
        state;
    long
        character_index;
    string[]
        word_array;

    word_array = [ "" ];
    state = 0;

    for ( character_index = 0;
          character_index < text.length;
          ++character_index )
    {
        character = text[ character_index ];

        if ( character == separator[ 0 ]
             && character_index + separator.length <= text.length
             && text[ character_index .. character_index + separator.length ] == separator )
        {
            word_array ~= "";
        }
        else
        {
            word_array[ word_array.length.to!long() - 1 ] ~= character;

            if ( "'\"`".indexOf( character ) >= 0 )
            {
                if ( state == 0 )
                {
                    state = character;
                }
                else if ( character == state )
                {
                    state = 0;
                }

            }
            else if ( character == '\\'
                      && character_index + 1 < text.length
                      && state != 0 )
            {
                ++character_index;

                word_array[ word_array.length.to!long() - 1 ] ~= text[ character_index ];
            }
        }
    }

    return word_array;
}

// ~~

bool HasEndingComment(
    string text
    )
{
    string[]
        word_array;

    word_array = GetWordArray( text, "//" );

    return word_array.length > 1;
}

// ~~

bool IsOpeningCommand(
    string stripped_line
    )
{
    return
        stripped_line == "#as"
        || stripped_line.startsWith( "#if " );
}

// ~~

bool EvaluateBooleanExpression(
    string boolean_expression
    )
{
    string
        old_boolean_expression;

    do
    {
        old_boolean_expression = boolean_expression;

        boolean_expression
            = boolean_expression
                  .replace( " ", "" )
                  .replace( "!false", "true" )
                  .replace( "!true", "false" )
                  .replace( "false&&false", "false" )
                  .replace( "false&&true", "false" )
                  .replace( "true&&false", "false" )
                  .replace( "true&&true", "true" )
                  .replace( "false||false", "false" )
                  .replace( "false||true", "true" )
                  .replace( "true||false", "true" )
                  .replace( "true||true", "true" )
                  .replace( "(true)", "true")
                  .replace( "(false)", "false" );
    }
    while ( boolean_expression != old_boolean_expression );

    if ( boolean_expression == "false" )
    {
        return false;
    }
    else if ( boolean_expression == "true" )
    {
        return true;
    }

    Abort( "Invalid boolean expression : " ~ boolean_expression );

    return false;
}

// ~~

void FindInputFiles(
    )
{
    long
        folder_path_index;
    string
        input_file_path,
        input_folder_path,
        output_file_path,
        output_folder_path;
    FILE *
        found_file;

    foreach ( file; FileMap )
    {
        file.Exists = false;
    }

    for ( folder_path_index = 0;
          folder_path_index < InputFolderPathArray.length;
          ++folder_path_index )
    {
        input_folder_path = InputFolderPathArray[ folder_path_index ];
        output_folder_path = OutputFolderPathArray[ folder_path_index ];

        foreach ( input_folder_entry; dirEntries( input_folder_path, "*.gs", SpanMode.depth ) )
        {
            if ( input_folder_entry.isFile() )
            {
                input_file_path = input_folder_entry.name();

                if ( input_file_path.startsWith( input_folder_path )
                     && input_file_path.endsWith( ".gs" ) )
                {
                    if ( output_folder_path == "" )
                    {
                        output_file_path = "";
                    }
                    else
                    {
                        output_file_path
                            = output_folder_path
                              ~ input_file_path[ input_folder_path.length .. $ - 3 ]
                              ~ ".go";
                    }

                    found_file = input_file_path in FileMap;

                    if ( found_file is null )
                    {
                        FileMap[ input_file_path ] = new FILE( input_file_path, output_file_path );
                    }
                    else
                    {
                        found_file.Exists = true;
                    }
                }
            }
        }
    }

    foreach ( file; FileMap )
    {
        if ( !file.Exists )
        {
            file.Text = "";
        }
    }
}

// ~~

void ReadInputFiles(
    )
{
    foreach ( file; FileMap )
    {
        if ( file.Exists )
        {
            file.ReadInputFile();
            file.ParseDefinitions();
        }
    }
}

// ~~

void WriteOutputFiles(
    )
{
    foreach ( file; FileMap )
    {
        if ( file.Exists
             && file.OutputPath != "" )
        {
            file.ApplyDefinitions();
            file.ApplyConditions();
            file.ApplyTemplates();
            file.JoinStatements();
            file.WriteOutputFile();
        }
    }
}

// ~~

void ProcessFiles(
    bool modification_time_is_used
    )
{
    bool
        files_are_processed;

    DefinitionArray = null;

    FindInputFiles();

    files_are_processed = false;

    foreach ( file; FileMap )
    {
        if ( file.Exists )
        {
            file.CheckChange( modification_time_is_used );

            if ( file.IsProcessed )
            {
                files_are_processed = true;
            }
        }
    }

    if ( files_are_processed )
    {
        ReadInputFiles();
        WriteOutputFiles();
    }
}

// ~~

void WatchFiles(
    )
{
    ProcessFiles( false );

    writeln( "Watching files..." );

    while ( true )
    {
        Thread.sleep( dur!( "msecs" )( PauseDuration ) );

        ProcessFiles( true );
    }
}

// ~~

void main(
    string[] argument_array
    )
{
    string
        input_folder_path,
        option,
        output_folder_path;

    argument_array = argument_array[ 1 .. $ ];

    SpaceText = " ";

    InputFolderPathArray = null;
    OutputFolderPathArray = null;
    JoinOptionIsEnabled = false;
    CreateOptionIsEnabled = false;
    WatchOptionIsEnabled = false;
    PauseDuration = 500;
    TabulationSpaceCount = 4;

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];

        argument_array = argument_array[ 1 .. $ ];

        if ( option == "--parse"
             && argument_array.length >= 1
             && argument_array[ 0 ].GetLogicalPath().endsWith( '/' ) )
        {
            InputFolderPathArray ~= argument_array[ 0 ].GetLogicalPath();
            OutputFolderPathArray ~= "";

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--process"
             && argument_array.length >= 2
             && argument_array[ 0 ].GetLogicalPath().endsWith( '/' )
             && argument_array[ 1 ].GetLogicalPath().endsWith( '/' ) )
        {
            InputFolderPathArray ~= argument_array[ 0 ].GetLogicalPath();
            OutputFolderPathArray ~= argument_array[ 1 ].GetLogicalPath();

            argument_array = argument_array[ 2 .. $ ];
        }
        else if ( option == "--join" )
        {
            JoinOptionIsEnabled = true;
        }
        else if ( option == "--create" )
        {
            CreateOptionIsEnabled = true;
        }
        else if ( option == "--watch" )
        {
            WatchOptionIsEnabled = true;
        }
        else if ( option == "--pause"
                  && argument_array.length >= 1 )
        {
            PauseDuration = argument_array[ 0 ].to!long();

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--tabulation"
                  && argument_array.length >= 1 )
        {
            TabulationSpaceCount = argument_array[ 0 ].to!long();

            argument_array = argument_array[ 1 .. $ ];
        }
        else
        {
            PrintError( "Invalid option : " ~ option );
        }
    }

    if ( argument_array.length == 0 )
    {
        if ( WatchOptionIsEnabled )
        {
            WatchFiles();
        }
        else
        {
            ProcessFiles( false );
        }
    }
    else
    {
        writeln( "Usage :" );
        writeln( "    generis [options]" );
        writeln( "Options :" );
        writeln( "    --parse INPUT_FOLDER/" );
        writeln( "    --process INPUT_FOLDER/ OUTPUT_FOLDER/" );
        writeln( "    --join" );
        writeln( "    --create" );
        writeln( "    --watch" );
        writeln( "    --pause 500" );
        writeln( "    --tabulation 4" );
        writeln( "Examples :" );
        writeln( "    generis GS/ GO/" );
        writeln( "    generis --create GS/ GO/" );
        writeln( "    generis --create --watch GS/ GO/" );

        PrintError( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
