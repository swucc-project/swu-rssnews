using rssnews.Models;

namespace rssnews.GraphQL.Types
{
    public sealed class AuthorObject : ObjectType<Author>
    {
        protected override void Configure(IObjectTypeDescriptor<Author> descriptor)
        {
            descriptor.Name("Author");

            descriptor.Field(a => a.AuthorID)
                .Type<NonNullType<StringType>>()
                .Name("authorID")
                .Description("The unique identifier of the author.");

            descriptor.Field(a => a.FirstName)
                .Type<NonNullType<StringType>>()
                .Name("firstName")
                .Description("The name of the author.");

            descriptor.Field(a => a.LastName)
                .Type<NonNullType<StringType>>()
                .Name("lastName")
                .Description("The lastname of the author.");

            descriptor.Ignore(a => a.Items);
        }
    }
}